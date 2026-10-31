return function(Window)
    local Registry = Abysall.GameRegistry
    local Current = Abysall.CurrentGame
    local Library = Abysall.Interface.Library
    local Tab = Window:AddTab("Games", "gamepad-2")
    local Overview = Tab:AddLeftGroupbox("Supported Games")
    local Count = 0
    local Names, ByName = {}, {}
    for _, Entry in ipairs(Registry.Entries) do
        if not Entry.Fallback then Count = Count + 1 end
        table.insert(Names, Entry.Name)
        ByName[Entry.Name] = Entry
    end
    table.sort(Names)

    Overview:AddLabel(Count .. " game modules + Universal", true)
    Overview:AddLabel("Active: " .. Current.Name, true)
    Overview:AddLabel(Current.Fallback
        and "This experience uses the Universal tools."
        or "A dedicated module was detected for this experience.", true)
    Overview:AddDivider()
    Overview:AddDropdown("SupportedGame", {
        Text = "Browse games", Values = Names, Default = Current.Name,
        Searchable = true,
    })
    Overview:AddLabel("Browsing this list does not change your active module.", true)

    local Details = Tab:AddRightGroupbox("Game Details")
    local Name = Details:AddLabel("", true)
    local Support = Details:AddLabel("", true)
    local Coverage = Details:AddLabel("", true)
    Details:AddDivider()
    local Features = Details:AddLabel("", true)
    Details:AddDivider()
    local Updated = Details:AddLabel("", true)
    Details:AddLabel("Dates refer to this hub's module source updates.", true)

    local function ShowDetails(Value)
        local Entry = ByName[Value]
        if not Entry then return end
        Name:SetText(Entry.Name .. (Entry.Id == Current.Id and " (active)" or ""))
        Support:SetText("Support: " .. (Entry.Fallback and "Universal tools" or "Dedicated module"))
        Coverage:SetText("Available in: " .. Entry.Coverage)
        Features:SetText("Features:\n- " .. table.concat(Entry.Features, "\n- "))
        Updated:SetText("Module updated: " .. Entry.Updated)
    end
    local Selection = Library.Options.SupportedGame
    Selection:OnChanged(ShowDetails)
    ShowDetails(Selection.Value)
end
