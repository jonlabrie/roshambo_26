## Task 9: Client — Access panel section

**Files:**
- Modify: `roblox/src/client/TeahouseController.client.luau`

**Interfaces:**
- Consumes: `AccessState { mode, invited: { { userId, name } }, notice? }` (Task 5); fires `SetAccess { mode }`, `InviteUser { username }`, `RevokeUser { userId }`.
- Produces: the Access section (mode toggle + invite field + invitee list + notice).

> Roblox GUI file — no Lune coverage. Verify with `rojo build` + lint + the visual gate.

- [ ] **Step 1: Add the remote handles**

Near the other `remotes:WaitForChild` lines in `TeahouseController.client.luau`, add:

```lua
local SetAccess = remotes:WaitForChild("SetAccess") :: RemoteEvent
local InviteUser = remotes:WaitForChild("InviteUser") :: RemoteEvent
local RevokeUser = remotes:WaitForChild("RevokeUser") :: RemoteEvent
local AccessState = remotes:WaitForChild("AccessState") :: RemoteEvent
```

Add module state near the other latest-state locals (e.g. next to `backDoorIndex`):

```lua
local access = { mode = "public", invited = {} :: { { userId: number, name: string } } }
local accessNotice: string? = nil
```

- [ ] **Step 2: Build the Access section at construction time**

Add after the decorations section builders (before `render` is defined). Uses the existing palette locals (`BG`, `TEXT`, `GOLD`, `DIM`, `DANGER`):

```lua
sectionLabel(82, "Access")

-- mode toggle row (public / friends / private)
local accessModeRow = Instance.new("Frame")
accessModeRow.Name = "AccessModeRow"
accessModeRow.LayoutOrder = 83
accessModeRow.Size = UDim2.new(1, 0, 0, 30)
accessModeRow.BackgroundTransparency = 1
accessModeRow.Parent = panel
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = accessModeRow
end
local accessModeButtons: { [string]: TextButton } = {}
for i, mode in { "public", "friends", "private" } do
    local button = Instance.new("TextButton")
    button.Name = mode
    button.LayoutOrder = i
    button.Size = UDim2.fromOffset(100, 30)
    button.BackgroundColor3 = BG
    button.BackgroundTransparency = 0.1
    button.TextColor3 = TEXT
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.Text = mode:sub(1, 1):upper() .. mode:sub(2)
    button.Parent = accessModeRow
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    button.MouseButton1Click:Connect(function()
        SetAccess:FireServer({ mode = mode })
    end)
    accessModeButtons[mode] = button
end

-- invite field + button (shown only in private mode)
local inviteRow = Instance.new("Frame")
inviteRow.Name = "InviteRow"
inviteRow.LayoutOrder = 84
inviteRow.Size = UDim2.new(1, 0, 0, 30)
inviteRow.BackgroundTransparency = 1
inviteRow.Visible = false
inviteRow.Parent = panel
local inviteBox = Instance.new("TextBox")
inviteBox.Name = "InviteBox"
inviteBox.Size = UDim2.new(1, -70, 1, 0)
inviteBox.BackgroundColor3 = BG
inviteBox.BackgroundTransparency = 0.1
inviteBox.TextColor3 = TEXT
inviteBox.PlaceholderText = "username"
inviteBox.Font = Enum.Font.Gotham
inviteBox.TextSize = 12
inviteBox.ClearTextOnFocus = false
inviteBox.Text = ""
inviteBox.Parent = inviteRow
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = inviteBox
end
local inviteButton = Instance.new("TextButton")
inviteButton.Name = "InviteButton"
inviteButton.AnchorPoint = Vector2.new(1, 0)
inviteButton.Position = UDim2.fromScale(1, 0)
inviteButton.Size = UDim2.fromOffset(64, 30)
inviteButton.BackgroundColor3 = BG
inviteButton.BackgroundTransparency = 0.1
inviteButton.TextColor3 = GOLD
inviteButton.Font = Enum.Font.GothamBold
inviteButton.TextSize = 12
inviteButton.Text = "Invite"
inviteButton.Parent = inviteRow
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = inviteButton
end
inviteButton.MouseButton1Click:Connect(function()
    local name = inviteBox.Text
    if #name > 0 then
        InviteUser:FireServer({ username = name })
        inviteBox.Text = ""
    end
end)

local noticeLabel = Instance.new("TextLabel")
noticeLabel.Name = "AccessNotice"
noticeLabel.LayoutOrder = 85
noticeLabel.Size = UDim2.new(1, 0, 0, 16)
noticeLabel.BackgroundTransparency = 1
noticeLabel.TextColor3 = GOLD
noticeLabel.Font = Enum.Font.Gotham
noticeLabel.TextSize = 11
noticeLabel.TextXAlignment = Enum.TextXAlignment.Left
noticeLabel.Text = ""
noticeLabel.Visible = false
noticeLabel.Parent = panel

-- invitee list (shown only in private mode)
local inviteeContainer = Instance.new("ScrollingFrame")
inviteeContainer.Name = "Invitees"
inviteeContainer.LayoutOrder = 86
inviteeContainer.Size = UDim2.new(1, 0, 0, 96)
inviteeContainer.CanvasSize = UDim2.new()
inviteeContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
inviteeContainer.ScrollBarThickness = 6
inviteeContainer.BackgroundTransparency = 1
inviteeContainer.BorderSizePixel = 0
inviteeContainer.Visible = false
inviteeContainer.Parent = panel
local inviteeLayout = Instance.new("UIListLayout")
inviteeLayout.FillDirection = Enum.FillDirection.Vertical
inviteeLayout.Padding = UDim.new(0, 4)
inviteeLayout.SortOrder = Enum.SortOrder.LayoutOrder
inviteeLayout.Parent = inviteeContainer
```

- [ ] **Step 3: Add the access render helpers + call from `render()`**

Add a render helper (before `render`):

```lua
local function renderAccess()
    for mode, button in accessModeButtons do
        local selected = access.mode == mode
        button.TextColor3 = if selected then GOLD else TEXT
        button.BackgroundTransparency = if selected then 0 else 0.1
    end
    local isPrivate = access.mode == "private"
    inviteRow.Visible = isPrivate
    inviteeContainer.Visible = isPrivate
    noticeLabel.Visible = accessNotice ~= nil
    noticeLabel.Text = accessNotice or ""

    for _, child in inviteeContainer:GetChildren() do
        if child ~= inviteeLayout then
            child:Destroy()
        end
    end
    if isPrivate then
        for i, entry in access.invited do
            local row = Instance.new("Frame")
            row.Name = "Invitee_" .. tostring(entry.userId)
            row.LayoutOrder = i
            row.Size = UDim2.new(1, 0, 0, 22)
            row.BackgroundTransparency = 1
            row.Parent = inviteeContainer
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -28, 1, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = TEXT
            label.Font = Enum.Font.Gotham
            label.TextSize = 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = entry.name
            label.Parent = row
            local remove = Instance.new("TextButton")
            remove.AnchorPoint = Vector2.new(1, 0)
            remove.Position = UDim2.fromScale(1, 0)
            remove.Size = UDim2.fromOffset(22, 22)
            remove.BackgroundColor3 = BG
            remove.BackgroundTransparency = 0.1
            remove.TextColor3 = DANGER
            remove.Font = Enum.Font.GothamBold
            remove.TextSize = 14
            remove.Text = "x"
            remove.Parent = row
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 4)
            c.Parent = remove
            local uid = entry.userId
            remove.MouseButton1Click:Connect(function()
                RevokeUser:FireServer({ userId = uid })
            end)
        end
    end
end
```

In `render()`, after the decorations block (before `renderFavorites`), add:

```lua
    renderAccess()
```

Also make the whole Access section owner-only by hiding it when the player owns no deck (place these after `renderAccess()` in `render`, using the existing `vm.ownsDeck`):

```lua
    accessModeRow.Visible = vm.ownsDeck
    if not vm.ownsDeck then
        inviteRow.Visible = false
        inviteeContainer.Visible = false
        noticeLabel.Visible = false
    end
```

- [ ] **Step 4: Wire the `AccessState` echo**

Add near the other `OnClientEvent` handlers:

```lua
AccessState.OnClientEvent:Connect(function(p)
    if typeof(p) ~= "table" then
        return
    end
    access.mode = p.mode or "public"
    access.invited = p.invited or {}
    accessNotice = p.notice
    render()
end)
```

- [ ] **Step 5: Verify + lint**

Run: `cd roblox && rojo build -o /tmp/ac-t9-check.rbxl`
Expected: succeeds.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.
Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/client/TeahouseController.client.luau
git commit -m "feat(roblox): access panel section (mode toggle + invite/revoke)"
```

---

