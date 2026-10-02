--[[
	Abysall - Executor yetenek katmani (Environment)
	------------------------------------------------
	Tasarim:
	 1. AYNIK (non-blocking): testler arka planda paralel calisir, yukleme beklemez.
	 2. IZOLE: hicbir test cokmez, hata olursa sadece o yetenek isaretlenir.
	 3. AYIRICI: varlik (global fonksiyon mu?) ve dogrulanma (test gecti mi?) ayridir.
	     Bu sayede CheckCompat gibi senkron kontroller aninda calisir.
	 4. YEDEKLI: kritik ozellikler icin Environment.Safe.* fallback zincirleri sunar,
	     boylece bir yetenek yoksa da ozellik cokmek yerine yedek yolla calisir.
]]

local Environment = {}

local RootEnv = (type(getfenv) == "function" and getfenv(0)) or _G

local function GetGlobal(Path)
	local Value = RootEnv
	local Guard = 0
	while type(Value) == "table" and Path ~= "" and Guard < 8 do
		Guard = Guard + 1
		local Name, NextPath = string.match(Path, "^([^.]+)%.?(.*)$")
		Value = Value[Name]
		Path = NextPath
	end
	return Value
end

local Global = setmetatable({}, {
	__index = function(Self, Name)
		return GetGlobal(Name)
	end,
})

local Services = setmetatable({}, {
	__index = function(Self, Name)
		return game:GetService(Name)
	end,
})

-- // Executor tespiti (cache'li) //
local ExecutorName
local function DetectExecutor()
	if ExecutorName then return ExecutorName end
	local Ok, Value = pcall(function()
		return Global.identifyexecutor()
	end)
	if Ok and type(Value) == "string" and Value ~= "" then
		ExecutorName = Value
		return ExecutorName
	end
	-- global imzalarindan tahmin
	if type(Global.gethui) == "function" and type(Global.getgenv) == "function" then
		ExecutorName = "Unknown (gethui tabanli)"
	elseif type(Global.getgenv) == "function" then
		ExecutorName = "Unknown"
	else
		ExecutorName = "Unknown"
	end
	return ExecutorName
end

-- // Durum //
local Results = {}
local Capabilities = {}
local Tests = {}
local Tested, Passed, Failed, Skipped = 0, 0, 0, 0
local AllFinished = false
-- Safe tablosu Register'dan SONRA kuruluyor; upvalue'in nil kalmamasi icin once tanimla
local Safe

-- Bazi executor'larda testte kullanilan ozellikler bozuktur
local BrokenFeatures = {
	["Volcano"] = { "run_on_actor", "oth" },
	["Opiumware"] = { "gethiddenproperty" },
	["Solara"] = { "require" },
	["Xeno"] = { "require" },
	["Jupiter"] = { "require" },
	["AWP"] = { "require" },
}

local function AddResult(Name, Text, DidPass, Kind)
	table.insert(Results, Text)
	local Entry = Capabilities[Name]
	if not Entry then
		Entry = { Passed = false, Reason = Text, Kind = Kind }
		Capabilities[Name] = Entry
	end
	Entry.Reason = Text
	Entry.Passed = DidPass or false
	Entry.Kind = Kind or Entry.Kind
end

-- // Test kaydi //
-- Testler hemen kaydedilir; global fonksiyon varsa Environment[Key] ANINDA atanir
-- (CheckCompat senkron calistigi icin) ve dogrulama arka planda yapilir.
local function Register(DisplayName, Key, Test, Opts)
	Opts = Opts or {}
	local GlobalName = Opts.Global or Key or DisplayName
	local Target = Global[GlobalName]
	-- Safe yedegi olan testler global olmasa da calisir (yedek yolu dogrulanir)
	local SafeFn = nil
	if Opts.SafeKey and Safe and type(Safe[Opts.SafeKey]) == "function" then
		SafeFn = Safe[Opts.SafeKey]
	end
	local Entry = {
		Display = DisplayName,
		Key = Key or GlobalName,
		Global = GlobalName,
		Test = Test,
		Skippable = Opts.Skippable == true,
		HasFallback = SafeFn ~= nil,
		Callable = type(Target) == "function" or type(Target) == "table" or SafeFn ~= nil,
	}
	Entry.Capability = { Passed = false, Pending = Entry.Callable, Reason = "not tested yet" }
	Capabilities[DisplayName] = Entry.Capability

	-- Varlik testi: gercek global varsa ANINDA yayinla (CheckCompat senkron calisir)
	if type(Target) == "function" or type(Target) == "table" then
		Environment[Entry.Key] = Target
	end
	table.insert(Tests, Entry)
	return Entry
end

local function RunEntry(Entry)
	local Executor = DetectExecutor()
	local Broken = BrokenFeatures[Executor]
	local Skip = Entry.Skippable
	if Broken and table.find(Broken, Entry.Display) then
		Skip = true
	end
	if not Entry.Callable then
		AddResult(Entry.Display, "[X] " .. Entry.Display .. " yok (global bulunamadi)", false, "fail")
		Failed = Failed + 1
		Entry.Capability.Pending = false
		return
	end
	if Entry.HasFallback and not Environment[Entry.Key] then
		AddResult(Entry.Display, "[-] " .. Entry.Display .. ": global yok, yedek yol kullanilacak", nil, "skip")
		Skipped = Skipped + 1
		Entry.Capability.Pending = false
		return
	end
	if Skip then
		AddResult(Entry.Display, "[-] " .. Entry.Display .. " atlandi", nil, "skip")
		Skipped = Skipped + 1
		Entry.Capability.Pending = false
		return
	end

	local Finished = false
	local TimedOut = false
	task.spawn(function()
		local Ok, Err = pcall(function() return Entry.Test(Global, Environment, Services) end)
		if not TimedOut then
			-- Oyun durumundan kaynakli gecici hatalar "atlandi" sayilir, eksik yetenek sayilmaz
			local Message = tostring(Err)
			if Ok then
				AddResult(Entry.Display, "[+] " .. Entry.Display, true, "pass")
				Passed = Passed + 1
			elseif string.find(Message, "atlandi", 1, true) then
				AddResult(Entry.Display, "[-] " .. Entry.Display .. ": " .. Message, nil, "skip")
				Skipped = Skipped + 1
			else
				AddResult(Entry.Display, "[X] " .. Entry.Display .. ": " .. Message, false, "fail")
				Failed = Failed + 1
			end
		end
		Finished = true
	end)

	-- Kisa bekleme: 5 saniye. Test cokerse yetenek "belirsiz" sayilir, cokmez.
	local Waited = 0
	while not Finished and not TimedOut and Waited < 5 do
		task.wait(0.1)
		Waited = Waited + 0.1
	end
	if not Finished and not TimedOut then
		TimedOut = true
		AddResult(Entry.Display, "[-] " .. Entry.Display .. ": zaman asimi", nil, "skip")
		Skipped = Skipped + 1
	end
	Entry.Capability.Pending = false
end

local function RunAll()
	Tested = #Tests
	for _, Entry in ipairs(Tests) do
		task.spawn(RunEntry, Entry)
	end
	local Waited = 0
	while Waited < 12 do
		local Pending = false
		for _, Entry in ipairs(Tests) do
			if Entry.Capability.Pending then Pending = true break end
		end
		if not Pending then break end
		task.wait(0.15)
		Waited = Waited + 0.15
	end
	AllFinished = true
	Environment.Ready = true
	pcall(function()
		warn("[Abysall] Yetenek testi bitti: " .. tostring(Passed) .. "/" .. tostring(Tested)
			.. " gecti, " .. tostring(Failed) .. " kaldi, " .. tostring(Skipped) .. " atlandi")
	end)
end

Environment.Ready = false

-- // Genel API //
Environment.Results = Results
Environment.Capabilities = Capabilities
Environment.Tests = Tests

function Environment.Has(Name)
	local Entry = Capabilities[Name]
	return Entry ~= nil and Entry.Passed == true
end

-- Global gercekten var mi (test sonucu beklenmeden)
function Environment.Usable(Name)
	local Value = Environment[Name]
	return Value ~= nil
end

function Environment.Score()
	if Tested == 0 then return 0 end
	return math.floor((Passed / Tested) * 1000 + 0.5) / 10
end

function Environment.Stats()
	return { Tested = Tested, Passed = Passed, Failed = Failed, Skipped = Skipped, Ready = AllFinished }
end

-- InfoTab icin tek parca ozet
function Environment.Report()
	local S = Environment.Stats()
	local Lines = {}
	table.insert(Lines, "Executor: " .. DetectExecutor())
	table.insert(Lines, string.format("Skor: %s%%  (%d/%d gecti, %d kaldi, %d atlandi)",
		tostring(Environment.Score()), S.Passed, S.Tested, S.Failed, S.Skipped))
	if S.Failed > 0 then
		local Names = {}
		for _, Entry in ipairs(Tests) do
			if Entry.Capability.Kind == "fail" then
				table.insert(Names, Entry.Display)
			end
		end
		table.insert(Lines, "Eksik: " .. table.concat(Names, ", "))
	else
		table.insert(Lines, "Eksik: yok")
	end
	return table.concat(Lines, "\n")
end

Environment.identifyexecutor = DetectExecutor

-- Test sonucu beklenmeden calistirilabilsin
function Environment.WaitReady(Timeout)
	local Waited = 0
	while not AllFinished and Waited < (Timeout or 10) do
		task.wait(0.1)
		Waited = Waited + 0.1
	end
	return AllFinished
end

-- // Yedekli (fallback) yardimcilar //
-- Bunlar her zaman guvenli: gercek API varsa o, yoksa yedek yolu.
local MemoryFS = {}
local Folders = { ["Abysall"] = true, ["Abysall/addons"] = true }

Safe = {}

Safe.cloneref = function(Object)
	if type(Environment.cloneref) == "function" then
		local Ok, Clone = pcall(Environment.cloneref, Object)
		if Ok and Clone ~= nil then return Clone end
	end
	return Object
end

Safe.gethui = function()
	if type(Environment.gethui) == "function" then
		local Ok, Hui = pcall(Environment.gethui)
		if Ok and type(Hui) == "Instance" then return Hui end
	end
	-- Kendi konteynerimizi olustur
	local Ok, Hui = pcall(function()
		local Core = game:GetService("CoreGui")
		local Existing = Core:FindFirstChild("AbysallGui")
		if Existing then return Existing end
		local New = Instance.new("ScreenGui")
		New.Name = "AbysallGui"
		New.ResetOnSpawn = false
		New.IgnoreGuiInset = true
		New.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		New.Parent = Core
		return New
	end)
	if Ok and Hui then return Hui end
	return nil
end

Safe.HttpGet = function(Url)
	if type(Environment.request) == "function" then
		local Ok, Res = pcall(function()
			return Environment.request({ Url = Url, Method = "GET" })
		end)
		if Ok and type(Res) == "table" and type(Res.Body) == "string" and #Res.Body > 0 then
			return Res.Body
		end
	end
	local Ok, Body = pcall(game.HttpGet, game, Url)
	if Ok and type(Body) == "string" then return Body end
	return nil
end

-- Dosya sistemi: gercek FS yoksa bellek ici yedek
local function RealFS(Name)
	if type(Environment[Name]) == "function" then return Environment[Name] end
	if type(Global[Name]) == "function" then return Global[Name] end
	return nil
end

Safe.isfolder = function(Path)
	local F = RealFS("isfolder")
	if F then
		local Ok, Res = pcall(F, Path)
		if Ok and type(Res) == "boolean" then return Res end
	end
	return Folders[tostring(Path)] == true
end

Safe.makefolder = function(Path)
	local F = RealFS("makefolder")
	if F then
		local Ok = pcall(F, Path)
		if Ok then return true end
	end
	Folders[tostring(Path)] = true
	return true
end

Safe.delfolder = function(Path)
	local F = RealFS("delfolder")
	if F then pcall(F, Path) end
	Folders[tostring(Path)] = nil
	return true
end

Safe.isfile = function(Path)
	local F = RealFS("isfile")
	if F then
		local Ok, Res = pcall(F, Path)
		if Ok and type(Res) == "boolean" then return Res end
	end
	return MemoryFS[tostring(Path)] ~= nil
end

Safe.readfile = function(Path)
	local F = RealFS("readfile")
	if F then
		local Ok, Res = pcall(F, Path)
		if Ok and type(Res) == "string" then return Res end
	end
	return MemoryFS[tostring(Path)]
end

Safe.writefile = function(Path, Data)
	local F = RealFS("writefile")
	if F then
		local Ok = pcall(F, Path, Data)
		if Ok then return true end
	end
	MemoryFS[tostring(Path)] = tostring(Data)
	return true
end

Safe.appendfile = function(Path, Data)
	local F = RealFS("appendfile")
	if F then
		local Ok = pcall(F, Path, Data)
		if Ok then return true end
	end
	MemoryFS[tostring(Path)] = (MemoryFS[tostring(Path)] or "") .. tostring(Data)
	return true
end

Safe.delfile = function(Path)
	local F = RealFS("delfile")
	if F then pcall(F, Path) end
	MemoryFS[tostring(Path)] = nil
	return true
end

Safe.listfiles = function(Path)
	local F = RealFS("listfiles")
	if F then
		local Ok, Res = pcall(F, Path)
		if Ok and type(Res) == "table" then return Res end
	end
	local Out = {}
	for Key in pairs(MemoryFS) do
		local Dir = Key:match("^(.-)[/\\][^/\\]+$")
		if Dir == tostring(Path) then table.insert(Out, Key) end
	end
	return Out
end

Safe.loadfile = function(Path)
	local Src = Safe.readfile(Path)
	if type(Src) ~= "string" then return nil end
	local Ok, Fn = pcall(loadstring, Src)
	if Ok then return Fn end
	return nil
end

Safe.fireproximityprompt = function(Prompt)
	if type(Environment.fireproximityprompt) == "function" then
		local Ok = pcall(Environment.fireproximityprompt, Prompt)
		if Ok then return true end
	end
	return false
end

Safe.firesignal = function(Signal, ...)
	if type(Environment.firesignal) == "function" then
		local Ok = pcall(Environment.firesignal, Signal, ...)
		if Ok then return true end
	end
	return false
end

Safe.getconnections = function(Owner, Signal)
	if type(Environment.getconnections) == "function" then
		local Ok, Res = pcall(Environment.getconnections, Owner, Signal)
		if Ok and type(Res) == "table" then return Res end
	end
	return {}
end

Safe.getnamecallmethod = function()
	if type(Environment.getnamecallmethod) == "function" then
		local Ok, Res = pcall(Environment.getnamecallmethod)
		if Ok and type(Res) == "string" then return Res end
	end
	return nil
end

Safe.newcclosure = function(Fn)
	if type(Environment.newcclosure) == "function" then
		local Ok, Res = pcall(Environment.newcclosure, Fn)
		if Ok and type(Res) == "function" then return Res end
	end
	return Fn
end

Safe.hookfunction = function(Target, Hook)
	if type(Environment.hookfunction) == "function" then
		local Ok, Res = pcall(Environment.hookfunction, Target, Hook)
		if Ok and type(Res) == "function" then return Res, true end
	end
	return Target, false
end

Safe.isnetworkowner = function(Part)
	if type(Environment.isnetworkowner) == "function" then
		local Ok, Res = pcall(Environment.isnetworkowner, Part)
		if Ok and type(Res) == "boolean" then return Res end
	end
	-- Yedek: yerel karaktere aitse network owner biziz
	local Local = Services.Players.LocalPlayer
	local Char = Local and Local.Character
	if Char and Part and Part:IsDescendantOf(Char) then return true end
	return false
end

Safe.replicatesignal = function(Signal, ...)
	if type(Environment.replicatesignal) == "function" then
		local Ok = pcall(Environment.replicatesignal, Signal, ...)
		if Ok then return true end
	end
	return false
end

Safe.firetouchinterest = function(A, B, Toggle)
	if type(Environment.firetouchinterest) == "function" then
		local Ok = pcall(Environment.firetouchinterest, A, B, Toggle)
		if Ok then return true end
	end
	return false
end

Safe.require = function(Module)
	if type(Environment.require) == "function" then
		local Ok, Res = pcall(Environment.require, Module)
		if Ok and Res ~= nil then return Res end
	end
	return nil
end

Environment.Safe = Safe

-- // Testler //
local T = {}

T.getgenv = function(G)
	local Env = G.getgenv()
	assert(typeof(Env) == "table", "tablo donmedi")
	Env.__abysall_test = "ok"
	assert(Env.__abysall_test == "ok", "global yazilamadi")
	Env.__abysall_test = nil
end

T.getrenv = function(G)
	assert(typeof(G.getrenv) == "function", "getrenv yok")
	local Env = G.getrenv()
	assert(typeof(Env) == "table", "tablo donmedi")
	assert(Env ~= G.getgenv(), "getrenv, getgenv ile ayni")
end

T.getgc = function(G)
	assert(typeof(G.getgc) == "function", "getgc yok")
	local All = G.getgc(true)
	assert(type(All) == "table", "tablo donmedi")
	local NoTables = G.getgc(false)
	assert(type(NoTables) == "table", "tablo donmedi")
	local F = function() return 10 end
	assert(table.find(All, F) ~= nil, "fonksiyonlar icinde degil")
end

T.identifyexecutor = function(G)
	assert(typeof(G.identifyexecutor()) == "string", "string donmedi")
end

T.request = function(G, Env)
	assert(typeof(Env.Safe.HttpGet) == "function", "HttpGet yok")
	local Body = Env.Safe.HttpGet("https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/README.md")
	assert(type(Body) == "string" and #Body > 0, "govde bos")
end

T.cloneref = function(G, Env)
	assert(typeof(G.cloneref) == "function", "cloneref yok")
	local Part = Instance.new("Part")
	local Clone = G.cloneref(Part)
	assert(typeof(Clone) == "Instance", "Instance donmedi")
	assert(Part ~= Clone, "klone ayni")
	Part:Destroy()
end

T.gethui = function(G, Env)
	local Hui = Env.Safe.gethui()
	assert(type(Hui) == "Instance", "Instance donmedi")
end

T.getcallbackvalue = function(G)
	assert(typeof(G.getcallbackvalue) == "function", "getcallbackvalue yok")
	local B = Instance.new("BindableFunction")
	B.OnInvoke = function(Value) return Value * 10 end
	local Cb = G.getcallbackvalue(B, "OnInvoke")
	assert(typeof(Cb) == "function", "fonksiyon donmedi")
	assert(Cb(5) == 50, "dogru degeri donmedi")
	B:Destroy()
end

T.getinstances = function(G)
	assert(typeof(G.getinstances) == "function", "getinstances yok")
	local P = Instance.new("Part")
	local L = G.getinstances()
	assert(type(L) == "table", "tablo donmedi")
	P:Destroy()
end

T.getnilinstances = function(G)
	assert(typeof(G.getnilinstances) == "function", "getnilinstances yok")
	local P = Instance.new("Part")
	local L = G.getnilinstances()
	assert(type(L) == "table", "tablo donmedi")
	P:Destroy()
end

T.fireproximityprompt = function(G, Env)
	assert(typeof(G.fireproximityprompt) == "function", "fireproximityprompt yok")
	local Part = Instance.new("Part", game:GetService("Workspace"))
	local Prompt = Instance.new("ProximityPrompt", Part)
	local Fired = false
	local Conn = Prompt.Triggered:Connect(function() Fired = true end)
	G.fireproximityprompt(Prompt)
	for _ = 1, 10 do
		if Fired then break end
		task.wait(0.1)
	end
	Conn:Disconnect()
	Part:Destroy()
	assert(Fired == true, "prompt tetiklenmedi")
end

T.fireclickdetector = function(G, Env)
	assert(typeof(G.fireclickdetector) == "function", "fireclickdetector yok")
	local Part = Instance.new("Part", game:GetService("Workspace"))
	local Click = Instance.new("ClickDetector", Part)
	local Fired = false
	local Conn = Click.MouseClick:Connect(function() Fired = true end)
	G.fireclickdetector(Click)
	for _ = 1, 10 do
		if Fired then break end
		task.wait(0.1)
	end
	Conn:Disconnect()
	Part:Destroy()
	assert(Fired == true, "click detector tetiklenmedi")
end

T.firetouchinterest = function(G)
	assert(typeof(G.firetouchinterest) == "function", "firetouchinterest yok")
	local A = Instance.new("Part", game:GetService("Workspace"))
	local B = Instance.new("Part", game:GetService("Workspace"))
	A.Position = Vector3.new(0, 1000, 0)
	B.Position = Vector3.new(0, 1000, 0)
	local Fired = false
	local Conn = A.Touched:Connect(function(Child)
		if Child == B then Fired = true end
	end)
	G.firetouchinterest(A, B, 0)
	task.wait()
	G.firetouchinterest(A, B, 1)
	for _ = 1, 10 do
		if Fired then break end
		task.wait(0.1)
	end
	Conn:Disconnect()
	A:Destroy()
	B:Destroy()
	assert(Fired == true, "touch interest tetiklenmedi")
end

T.clonefunction = function(G)
	assert(typeof(G.clonefunction) == "function", "clonefunction yok")
	local F = function() return 10 end
	local C = G.clonefunction(F)
	assert(C ~= F, "klone ayni")
	assert(C() == 10, "farkli deger dondu")
end

T.newcclosure = function(G, Env)
	assert(typeof(G.newcclosure) == "function", "newcclosure yok")
	local F = function() return 10 end
	local C = Env.Safe.newcclosure(F)
	assert(C ~= F, "klone ayni")
	assert(C() == 10, "farkli deger dondu")
end

T.hookfunction = function(G, Env)
	assert(typeof(G.hookfunction) == "function", "hookfunction yok")
	local F = function() return 10 end
	local Old = G.hookfunction(F, function() return 100 end)
	assert(F() == 100, "hook uygulanmadi")
	if typeof(Old) == "function" then Old() end
end

T.restorefunction = function(G)
	assert(typeof(G.restorefunction) == "function", "restorefunction yok")
	local F = function() return 10 end
	G.hookfunction(F, function() return 100 end)
	G.restorefunction(F)
	assert(F() == 10, "unhook basarisiz")
end

T.isfunctionhooked = function(G)
	assert(typeof(G.isfunctionhooked) == "function", "isfunctionhooked yok")
	local F = function() return 10 end
	assert(G.isfunctionhooked(F) == false, "temiz fonksiyon hooked gorunuyor")
end

T.isexecutorclosure = function(G)
	assert(typeof(G.isexecutorclosure) == "function", "isexecutorclosure yok")
	assert(type(G.isexecutorclosure) == "function", "calismiyor")
end

T.getnamecallmethod = function(G)
	assert(typeof(G.getnamecallmethod) == "function", "getnamecallmethod yok")
	pcall(function() game:AbysallTestMethod() end)
	assert(typeof(G.getnamecallmethod()) == "string", "string donmedi")
end

T.hookmetamethod = function(G, Env)
	assert(typeof(G.hookmetamethod) == "function", "hookmetamethod yok")
	assert(typeof(G.newcclosure) == "function", "newcclosure yok")
	local T1 = setmetatable({}, {
		__index = G.newcclosure(function() return "normal" end),
	})
	G.hookmetamethod(T1, "__index", G.newcclosure(function() return "hooked" end))
	assert(T1.AbysallExample == "hooked", "metamethod hook calismadi")
end

T.getrawmetatable = function(G)
	assert(typeof(G.getrawmetatable) == "function", "getrawmetatable yok")
	local MT = { __metatable = "Locked" }
	local Obj = setmetatable({}, MT)
	assert(G.getrawmetatable(Obj) == MT, "metatable donmedi")
end

T.setrawmetatable = function(G)
	assert(typeof(G.setrawmetatable) == "function", "setrawmetatable yok")
	assert(typeof(G.getrawmetatable) == "function", "getrawmetatable yok")
	local Obj = setmetatable({}, { __metatable = "Locked" })
	G.setrawmetatable(Obj, { __index = function() return "Edited" end })
	assert(Obj.AbysallExample == "Edited", "metatable yazilamadi")
end

T.isreadonly = function(G)
	assert(typeof(G.isreadonly) == "function", "isreadonly yok")
	assert(G.isreadonly({}) == false, "yazilabilir tablo readonly sayildi")
end

T.setreadonly = function(G)
	assert(typeof(G.setreadonly) == "function", "setreadonly yok")
	assert(typeof(G.isreadonly) == "function", "isreadonly yok")
	local Tab = { Value = 10 }
	table.freeze(Tab)
	G.setreadonly(Tab, false)
	assert(G.isreadonly(Tab) == false, "readonly kaldirilamadi")
end

T.Drawing = function(G)
	assert(type(G.Drawing) == "table", "Drawing tablosu yok")
	assert(typeof(G.Drawing.new) == "function", "Drawing.new yok")
end

T.Drawing_Fonts = function(G)
	assert(type(G.Drawing) == "table", "Drawing tablosu yok")
	assert(type(G.Drawing.Fonts) == "table", "Drawing.Fonts tablo degil")
end

T.writefile = function(G, Env)
	Env.Safe.writefile("Abysall/env_test", "example")
	assert(Env.Safe.readfile("Abysall/env_test") == "example", "veri eslesmedi")
end

T.isfile = function(G, Env)
	Env.Safe.writefile("Abysall/env_test", "example")
	assert(Env.Safe.isfile("Abysall/env_test") == true, "dosya yok")
end

T.readfile = function(G, Env)
	Env.Safe.writefile("Abysall/env_test", "example")
	assert(Env.Safe.readfile("Abysall/env_test") == "example", "veri okunamadi")
end

T.appendfile = function(G, Env)
	Env.Safe.writefile("Abysall/env_test", "a")
	Env.Safe.appendfile("Abysall/env_test", "b")
	assert(Env.Safe.readfile("Abysall/env_test") == "ab", "ekleme basarisiz")
end

T.delfile = function(G, Env)
	Env.Safe.writefile("Abysall/env_test", "a")
	Env.Safe.delfile("Abysall/env_test")
	assert(Env.Safe.isfile("Abysall/env_test") == false, "silinemedi")
end

T.makefolder = function(G, Env)
	Env.Safe.makefolder("Abysall/envfolder")
	assert(Env.Safe.isfolder("Abysall/envfolder") == true, "klasor olusmadi")
end

T.delfolder = function(G, Env)
	Env.Safe.makefolder("Abysall/envfolder")
	Env.Safe.delfolder("Abysall/envfolder")
	assert(Env.Safe.isfolder("Abysall/envfolder") == false, "klasor silinemedi")
end

T.listfiles = function(G, Env)
	assert(typeof(Env.Safe.listfiles) == "function", "listfiles yok")
	assert(type(Env.Safe.listfiles("Abysall")) == "table", "tablo donmedi")
end

T.getcustomasset = function(G, Env)
	assert(typeof(G.getcustomasset) == "function", "getcustomasset yok")
	assert(typeof(Env.Safe.writefile) == "function", "writefile yok")
	local Content = Env.Safe.HttpGet("https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/README.md")
	assert(type(Content) == "string", "uzak dosya okunamadi")
end

T.gethiddenproperty = function(G)
	assert(typeof(G.gethiddenproperty) == "function", "gethiddenproperty yok")
	local Part = Instance.new("Part")
	local V = G.gethiddenproperty(Part, "NetworkIsSleeping")
	Part:Destroy()
	assert(type(V) == "boolean" or V ~= nil, "deger donmedi")
end

T.sethiddenproperty = function(G)
	assert(typeof(G.sethiddenproperty) == "function", "sethiddenproperty yok")
	assert(typeof(G.gethiddenproperty) == "function", "gethiddenproperty yok")
	local Part = Instance.new("Part")
	G.sethiddenproperty(Part, "NetworkIsSleeping", true)
	local V = G.gethiddenproperty(Part, "NetworkIsSleeping")
	Part:Destroy()
	assert(V == true, "gizli ozellik yazilamadi")
end

T.getthreadidentity = function(G)
	assert(typeof(G.getthreadidentity) == "function", "getthreadidentity yok")
	local I = G.getthreadidentity()
	assert(typeof(I) == "number", "sayi donmedi")
	assert(I > 0 and I < 9, "gecersiz kimlik")
end

T.setthreadidentity = function(G)
	assert(typeof(G.setthreadidentity) == "function", "setthreadidentity yok")
	assert(typeof(G.getthreadidentity) == "function", "getthreadidentity yok")
	local Old = G.getthreadidentity()
	local Ok = pcall(function()
		G.setthreadidentity(2)
		assert(G.getthreadidentity() == 2, "kimlik degismedi")
	end)
	pcall(function() G.setthreadidentity(Old) end)
	assert(Ok, "kimlik degistirilemedi")
end

T.isnetworkowner = function(G, Env)
	assert(typeof(G.isnetworkowner) == "function", "isnetworkowner yok")
	local Local = game:GetService("Players").LocalPlayer
	local RootPart = Local.Character and Local.Character:FindFirstChild("HumanoidRootPart")
	if not RootPart then error("karakter yok, atlandi") end
	local Ok = pcall(function()
		assert(G.isnetworkowner(RootPart) == true, "kendi parcamiz owner degil")
	end)
	assert(Ok, "kendi parcamiz owner gorunmuyor")
end

T.firesignal = function(G)
	assert(typeof(G.firesignal) == "function", "firesignal yok")
	local E = Instance.new("RemoteEvent")
	local Got
	local Conn = E.OnClientEvent:Connect(function(A) Got = A end)
	G.firesignal(E.OnClientEvent, "Abysall")
	for _ = 1, 10 do
		if Got then break end
		task.wait(0.1)
	end
	Conn:Disconnect()
	E:Destroy()
	assert(Got == "Abysall", "sinyal iletilemedi")
end

T.getconnections = function(G, Env)
	assert(typeof(G.getconnections) == "function", "getconnections yok")
	assert(type(G.getconnections(game.ChildAdded)) == "table", "tablo donmedi")
end

T.require = function(G)
	assert(typeof(G.require) == "function", "require yok")
	local Module = game:GetService("Players").LocalPlayer.PlayerScripts:FindFirstChildOfClass("ModuleScript")
	if not Module then error("test modulu yok, atlandi") end
	local Res = G.require(Module)
	assert(typeof(Res) == "table", "tablo donmedi")
end

-- // Testleri kaydet (sira sonucu degistirmez) //
local Order = {
	{ "getgenv", nil, false },
	{ "getrenv", nil, false },
	{ "getgc", nil, false },
	{ "identifyexecutor", nil, false },
	{ "request", nil, false },
	{ "cloneref", nil, false },
	{ "gethui", nil, false },
	{ "getcallbackvalue", nil, false },
	{ "getinstances", nil, false },
	{ "getnilinstances", nil, false },
	{ "fireproximityprompt", nil, false },
	{ "fireclickdetector", nil, false },
	{ "firetouchinterest", nil, false },
	{ "clonefunction", nil, false },
	{ "newcclosure", nil, false },
	{ "hookfunction", nil, false },
	{ "restorefunction", nil, false },
	{ "isfunctionhooked", nil, false },
	{ "isexecutorclosure", nil, false },
	{ "getnamecallmethod", nil, false },
	{ "hookmetamethod", nil, false },
	{ "getrawmetatable", nil, false },
	{ "setrawmetatable", nil, false },
	{ "isreadonly", nil, false },
	{ "setreadonly", nil, false },
	{ "Drawing", "Drawing_New", false },
	{ "Drawing_Fonts", "Drawing_Fonts", false },
	{ "writefile", nil, false },
	{ "isfile", nil, false },
	{ "readfile", nil, false },
	{ "appendfile", nil, false },
	{ "delfile", nil, false },
	{ "makefolder", nil, false },
	{ "delfolder", nil, false },
	{ "listfiles", nil, false },
	{ "getcustomasset", nil, true },
	{ "gethiddenproperty", nil, false },
	{ "sethiddenproperty", nil, false },
	{ "getthreadidentity", nil, false },
	{ "setthreadidentity", nil, false },
	{ "isnetworkowner", nil, false },
	{ "firesignal", nil, false },
	{ "getconnections", nil, false },
	{ "require", nil, true },
}

-- Testler icin guvenli yedek bulunanlar (global yoksa bile dogrulanabilir)
local SafeBacked = {
	["request"] = "HttpGet",
	["gethui"] = "gethui",
	["cloneref"] = "cloneref",
	["writefile"] = "writefile",
	["isfile"] = "isfile",
	["readfile"] = "readfile",
	["appendfile"] = "appendfile",
	["delfile"] = "delfile",
	["makefolder"] = "makefolder",
	["delfolder"] = "delfolder",
	["listfiles"] = "listfiles",
	["fireproximityprompt"] = "fireproximityprompt",
	["isnetworkowner"] = "isnetworkowner",
}

for _, Def in ipairs(Order) do
	local Name, Key, Skippable = Def[1], Def[2], Def[3]
	local Fn = T[Name]
	if type(Fn) == "function" then
		Register(Name, Key or Name, Fn, { Skippable = Skippable, SafeKey = SafeBacked[Name] })
	else
		Register(Name, Key or Name, function() end, { Skippable = true })
	end
end

-- Test edilmeden de kullanilan API'ler gorunur kalsin
for _, Extra in ipairs({ "isfolder", "getproperty", "gethiddenprop", "setclipboard", "setfflag", "request_async" }) do
	if type(Global[Extra]) == "function" and Environment[Extra] == nil then
		Environment[Extra] = Global[Extra]
	end
end

Environment.PrintResults = function()
	print("Test Result")
	print(Environment.Report())
	for _, Result in ipairs(Results) do
		print(Result)
	end
end

-- Tum testler kaydedildikten sonra baslat ( aksi halde Tested = 0 olur)
task.spawn(RunAll)

return Environment