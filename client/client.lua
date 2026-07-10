--------------------------------------------------
------- SYNTAX FRAMES — cinematic camera ----------
--------------------------------------------------
-- Originally "Cinematic Cam" by kiminaze (Philipp Decker); reworked for Syntax.
-- This script is client sided.
-- v1.2.0: NativeUI menu replaced with a custom NUI panel (html/).
-- v1.3.0: arrow-key navigation, auto-clear filters, screenshot button.


--------------------------------------------------
------------------- VARIABLES --------------------
--------------------------------------------------

-- This function is loading your language file from 'config.lua'.
SelectLanguage(Config.language);

-- main variables
local cam = nil

local offsetRotX = 0.0
local offsetRotY = 0.0
local offsetRotZ = 0.0

local offsetCoords = {}
offsetCoords.x = 0.0
offsetCoords.y = 0.0
offsetCoords.z = 0.0

local precision = 1.0
local speed = 1.0

local currFilter = 1
local currFilterIntensity = 1.0

local freeFly = false

local charControl = false

local isAttached = false
local entity

-- NUI menu state
local menuOpen = false
local shooting = false      -- true while a screenshot is being captured

-- permissions
local whitelisted = nil

-- print error if no menu access was specified
if (not(Config.useButton or Config.useCommand)) then
    print(Config.strings.noAccessError)
end

-- OrbitalCam
local currOrbitSpeed = 0.1
local orbitControlsEnabled = true
local boneNames = {}
local currOrbitBone = 1

for name, id in pairs (bonesList) do
    boneNames[#boneNames + 1] = name
end



--------------------------------------------------
------------------ NUI HELPERS -------------------
--------------------------------------------------

-- push a partial state update to the panel (only when it is open)
local function NuiSync(patch)
    if (menuOpen) then
        SendNUIMessage({ action = 'sync', data = patch })
    end
end

local function BuildInitData()
    local camActive = (cam and DoesCamExist(cam)) or false

    local orbit = false
    if (GetResourceState("OrbitCam") == "started") then
        orbit = {
            active   = exports["OrbitCam"]:IsOrbitCamActive(),
            speed    = currOrbitSpeed,
            controls = orbitControlsEnabled,
            bones    = boneNames,
            bone     = currOrbitBone,
        }
    end

    return {
        strings = Config.strings,
        ranges = {
            speed     = { min = Config.minSpeed, max = Config.maxSpeed, step = 0.1 },
            precision = { min = Config.minPrecision, max = Config.maxPrecision, step = Config.incrPrecision },
            fov       = { min = Config.minFov, max = Config.maxFov, step = 1.0 },
            intensity = { min = 0.1, max = 2.0, step = 0.1 },
        },
        state = {
            camActive   = camActive,
            precision   = precision,
            speed       = speed,
            fov         = camActive and GetCamFov(cam) or GetGameplayCamFov(),
            filter      = currFilter,
            intensity   = currFilterIntensity,
            showMap     = not IsRadarHidden(),
            freeFly     = freeFly,
            charControl = charControl,
            attached    = isAttached,
        },
        filters       = Config.filterList,
        attachEnabled = not Config.noMetaGaming,
        orbit         = orbit,
    }
end

function OpenCamMenu()
    menuOpen = true
    cursorActive = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)  -- keyboard keeps flying the cam while the mouse drives the panel
    SendNUIMessage({ action = 'open', data = BuildInitData() })
end

function CloseCamMenu()
    menuOpen = false
    cursorActive = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    -- clear any active filter when the panel closes (filters only make sense while composing)
    ResetFilter()
end


--------------------------------------------------
---------------------- LOOP ----------------------
--------------------------------------------------
Citizen.CreateThread(function()
    if (Config.usePermissions) then
        -- Request permissions here:
        TriggerServerEvent('syntax_frames:server:requestPermissions')

        -- Wait for permission request answer
        while (whitelisted == nil) do
            Citizen.Wait(1000)
        end

        if (whitelisted == false) then
            return
        end
    end


    local pressedCount = 0

    while true do
        Citizen.Wait(1)

        -- open / close menu on button press
        if (Config.useButton) then
            if (IsDisabledControlPressed(1, Config.controls.controller.openMenu)) then
                pressedCount = pressedCount + 1
            elseif (IsDisabledControlJustReleased(1, Config.controls.controller.openMenu)) then
                pressedCount = 0
            end
            if (IsDisabledControlJustReleased(1, Config.controls.keyboard.openMenu) or pressedCount >= 60) then
                if (pressedCount >= 60) then pressedCount = 0 end
                if (menuOpen) then
                    CloseCamMenu()
                else
                    OpenCamMenu()
                end
            end
        end

        -- keep ESC from opening the pause menu while the panel has focus (keep-input passes it through)
        if (menuOpen) then
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
        end

        -- process cam controls if cam exists
        if (cam) then
            ProcessCamControls()
        end
    end
end)

if ( not Config.noMetaGaming ) then
    Citizen.CreateThread(function()
        if (Config.usePermissions) then
            -- Wait for permission request answer
            while (whitelisted == nil) do
                Citizen.Wait(1000)
            end

            if (whitelisted == false) then
                return
            end
        end


        while true do
            Citizen.Wait(500)

            if (menuOpen and cam) then
                local tempEntity = GetEntityInFrontOfCam()
                local txt = "-"
                if (DoesEntityExist(tempEntity)) then
                    if (IsEntityAVehicle(tempEntity)) then
                        txt = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(tempEntity)))
                    else
                        txt = GetEntityArchetypeName(tempEntity)
                    end
                end
                NuiSync({ attachLabel = txt, attached = isAttached })

                if (isAttached and not DoesEntityExist(entity)) then
                    isAttached = false

                    ClearFocus()

                    StopCamPointing(cam)

                    NuiSync({ attached = false })
                end
            end
        end
    end)
end



--------------------------------------------------
------------------- FUNCTIONS --------------------
--------------------------------------------------

-- initialize camera
function StartFreeCam(fov)
    ClearFocus()

    local playerPed = PlayerPedId()

    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", GetEntityCoords(playerPed), 0, 0, 0, fov * 1.0)

    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)

    SetCamAffectsAiming(cam, false)

    if ( Config.noMetaGaming ) then
        ToggleAttachMode(PlayerPedId())
    end

    if (isAttached and DoesEntityExist(entity)) then
        offsetCoords = GetOffsetFromEntityGivenWorldCoords(entity, GetCamCoord(cam))

        AttachCamToEntity(cam, entity, offsetCoords.x, offsetCoords.y, offsetCoords.z, true)
    end
end

-- destroy camera
function EndFreeCam()
    ClearFocus()

    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(cam, false)

    offsetRotX = 0.0
    offsetRotY = 0.0
    offsetRotZ = 0.0

    isAttached = false

    speed       = 1.0
    precision   = 1.0

    cam = nil

    -- clear any active filter so the tint doesn't bleed into normal gameplay
    ResetFilter()

    NuiSync({ camActive = false, speed = speed, attached = false, fov = GetGameplayCamFov() })
end

-- process camera controls
function ProcessCamControls()
    -- disable 1st person as the 1st person camera can cause some glitches
    DisableFirstPersonCamThisFrame()
    -- block weapon wheel (reason: scrolling)
    BlockWeaponWheelThisFrame()
    -- disable character/vehicle controls
    if (not charControl) then
        for k, v in pairs(Config.disabledControls) do
            DisableControlAction(0, v, true)
        end
    end

    if (isAttached) then
        -- calculate new position
        offsetCoords = ProcessNewPosition(offsetCoords.x, offsetCoords.y, offsetCoords.z)

        -- focus entity
        SetFocusEntity(entity)

        -- reset coords of cam if too far from entity
        local distance = #(vector3(offsetCoords.x, offsetCoords.y, offsetCoords.z))
        if (distance > Config.maxDistance) then
            local factor = distance / Config.maxDistance
            offsetCoords = vector3(offsetCoords.x, offsetCoords.y, offsetCoords.z) / factor
        end

        -- set coords
        AttachCamToEntity(cam, entity, offsetCoords.x, offsetCoords.y, offsetCoords.z, true)

        -- set rotation
        local entityRot = GetEntityRotation(entity, 2)
        SetCamRot(cam, entityRot.x + offsetRotX, entityRot.y + offsetRotY, entityRot.z + offsetRotZ, 2)
    else
        local camCoords = GetCamCoord(cam)

        -- calculate new position
        local newPos = ProcessNewPosition(camCoords.x, camCoords.y, camCoords.z)

        -- focus cam area
        SetFocusArea(newPos.x, newPos.y, newPos.z, 0.0, 0.0, 0.0)

        -- set coords of cam
        SetCamCoord(cam, newPos.x, newPos.y, newPos.z)

        -- set rotation
        SetCamRot(cam, offsetRotX, offsetRotY, offsetRotZ, 2)
    end
end

function ProcessNewPosition(x, y, z)
    local _x = x
    local _y = y
    local _z = z

    -- keyboard
    if (IsInputDisabled(0) and not charControl) then
        if (IsDisabledControlPressed(1, Config.controls.keyboard.forwards)) then
            local multX = Sin(offsetRotZ)
            local multY = Cos(offsetRotZ)
            local multZ = Sin(offsetRotX)

            _x = _x - (0.1 * speed * multX)
            _y = _y + (0.1 * speed * multY)
            if (freeFly) then
                _z = _z + (0.1 * speed * multZ)
            end
        end
        if (IsDisabledControlPressed(1, Config.controls.keyboard.backwards)) then
            local multX = Sin(offsetRotZ)
            local multY = Cos(offsetRotZ)
            local multZ = Sin(offsetRotX)

            _x = _x + (0.1 * speed * multX)
            _y = _y - (0.1 * speed * multY)
            if (freeFly) then
                _z = _z - (0.1 * speed * multZ)
            end
        end
        if (IsDisabledControlPressed(1, Config.controls.keyboard.left)) then
            local multX = Sin(offsetRotZ + 90.0)
            local multY = Cos(offsetRotZ + 90.0)
            local multZ = Sin(offsetRotY)

            _x = _x - (0.1 * speed * multX)
            _y = _y + (0.1 * speed * multY)
            if (freeFly) then
                _z = _z + (0.1 * speed * multZ)
            end
        end
        if (IsDisabledControlPressed(1, Config.controls.keyboard.right)) then
            local multX = Sin(offsetRotZ + 90.0)
            local multY = Cos(offsetRotZ + 90.0)
            local multZ = Sin(offsetRotY)

            _x = _x + (0.1 * speed * multX)
            _y = _y - (0.1 * speed * multY)
            if (freeFly) then
                _z = _z - (0.1 * speed * multZ)
            end
        end

        if (IsDisabledControlPressed(1, Config.controls.keyboard.up)) then
            _z = _z + (0.1 * speed)
        end
        if (IsDisabledControlPressed(1, Config.controls.keyboard.down)) then
            _z = _z - (0.1 * speed)
        end


        if (IsDisabledControlPressed(1, Config.controls.keyboard.hold)) then
            -- hotkeys for speed
            if (IsDisabledControlPressed(1, Config.controls.keyboard.speedUp)) then
                if ((speed + 0.1) < Config.maxSpeed) then
                    speed = speed + 0.1
                else
                    speed = Config.maxSpeed
                end
                NuiSync({ speed = speed })
            elseif (IsDisabledControlPressed(1, Config.controls.keyboard.speedDown)) then
                if ((speed - 0.1) > Config.minSpeed) then
                    speed = speed - 0.1
                else
                    speed = Config.minSpeed
                end
                NuiSync({ speed = speed })
            end
        else
            -- hotkeys for FoV
            if (IsDisabledControlPressed(1, Config.controls.keyboard.zoomOut)) then
                ChangeFov(1.0)
            elseif (IsDisabledControlPressed(1, Config.controls.keyboard.zoomIn)) then
                ChangeFov(-1.0)
            end
        end

        -- rotation
        offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision * 8.0)
        offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision * 8.0)
        if (IsDisabledControlPressed(1, Config.controls.keyboard.rollLeft)) then
            offsetRotY = offsetRotY - precision
        end
        if (IsDisabledControlPressed(1, Config.controls.keyboard.rollRight)) then
            offsetRotY = offsetRotY + precision
        end

    -- controller
    elseif (not charControl) then
        local multX = Sin(offsetRotZ)
        local multY = Cos(offsetRotZ)
        local multZ = Sin(offsetRotX)

        _x = _x - (0.1 * speed * multX * GetDisabledControlNormal(1, 32))
        _y = _y + (0.1 * speed * multY * GetDisabledControlNormal(1, 32))
        if (freeFly) then
            _z = _z + (0.1 * speed * multZ * GetDisabledControlNormal(1, 32))
        end

        _x = _x + (0.1 * speed * multX * GetDisabledControlNormal(1, 33))
        _y = _y - (0.1 * speed * multY * GetDisabledControlNormal(1, 33))
        if (freeFly) then
            _z = _z - (0.1 * speed * multZ * GetDisabledControlNormal(1, 33))
        end

        multX = Sin(offsetRotZ + 90.0)
        multY = Cos(offsetRotZ + 90.0)
        multZ = Sin(offsetRotY)
        _x = _x - (0.1 * speed * multX * GetDisabledControlNormal(1, 34))
        _y = _y + (0.1 * speed * multY * GetDisabledControlNormal(1, 34))
        if (freeFly) then
            _z = _z + (0.1 * speed * multZ * GetDisabledControlNormal(1, 34))
        end

        _x = _x + (0.1 * speed * multX * GetDisabledControlNormal(1, 35))
        _y = _y - (0.1 * speed * multY * GetDisabledControlNormal(1, 35))
        if (freeFly) then
            _z = _z - (0.1 * speed * multZ * GetDisabledControlNormal(1, 35))
        end

        -- FoV, Speed, Up/Down Movement
        if (GetDisabledControlNormal(1, 228) ~= 0.0) then
            if (IsDisabledControlPressed(1, Config.controls.controller.holdFov)) then
                ChangeFov(GetDisabledControlNormal(1, 228))
            elseif (IsDisabledControlPressed(1, Config.controls.controller.holdSpeed)) then
                local newSpeed = speed - (0.1 * GetDisabledControlNormal(1, 228))
                if (newSpeed > Config.minSpeed) then
                    speed = newSpeed
                else
                    speed = Config.minSpeed
                end
                NuiSync({ speed = speed })
            else
                _z = _z - (0.1 * speed * GetDisabledControlNormal(1, 228))
            end
        end
        if (GetDisabledControlNormal(1, 229) ~= 0.0) then
            if (IsDisabledControlPressed(1, Config.controls.controller.holdFov)) then
                ChangeFov(- GetDisabledControlNormal(1, 229))
            elseif (IsDisabledControlPressed(1, Config.controls.controller.holdSpeed)) then
                local newSpeed = speed + (0.1 * GetDisabledControlNormal(1, 229))
                if (newSpeed < Config.maxSpeed) then
                    speed = newSpeed
                else
                    speed = Config.maxSpeed
                end
                NuiSync({ speed = speed })
            else
                _z = _z + (0.1 * speed * GetDisabledControlNormal(1, 229))
            end
        end

        -- rotation
        offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision)
        offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision)
        if (IsDisabledControlPressed(1, Config.controls.controller.rollLeft)) then
            offsetRotY = offsetRotY - precision
        end
        if (IsDisabledControlPressed(1, Config.controls.controller.rollRight)) then
            offsetRotY = offsetRotY + precision
        end
    end

    if (offsetRotX > 90.0) then offsetRotX = 90.0 elseif (offsetRotX < -90.0) then offsetRotX = -90.0 end
    if (offsetRotY > 90.0) then offsetRotY = 90.0 elseif (offsetRotY < -90.0) then offsetRotY = -90.0 end
    if (offsetRotZ > 360.0) then offsetRotZ = offsetRotZ - 360.0 elseif (offsetRotZ < -360.0) then offsetRotZ = offsetRotZ + 360.0 end

    return {x = _x, y = _y, z = _z}
end

function ToggleCam(flag, fov)
    if (flag) then
        StartFreeCam(fov)
    else
        EndFreeCam()
    end
end

function ChangeFov(changeFov)
    if (DoesCamExist(cam)) then
        local currFov   = GetCamFov(cam)
        local newFov    = currFov + changeFov

        if ((newFov >= Config.minFov) and (newFov <= Config.maxFov)) then
            SetCamFov(cam, newFov)
            NuiSync({ fov = newFov })
        end
    end
end

function ChangePrecision(newPrecision)
    precision = newPrecision
end

function ToggleUI(flag)
    DisplayRadar(flag)
end

function ToggleFreeFlyMode(flag)
    freeFly = flag
end

function GetEntityInFrontOfCam()
    local _, forward, _, position = GetCamMatrix(cam)
    local offset = position + forward * 50.0

    local rayHandle = StartShapeTestRay(position.x, position.y, position.z, offset.x, offset.y, offset.z, 30, 0, 4)
    local _, _, _, _, hitEntity = GetShapeTestResult(rayHandle)
    return hitEntity
end

function ToggleCharacterControl(flag)
    charControl = flag
end

function ToggleAttachMode(playerEntity)
    if (not isAttached) then
        entity = playerEntity or GetEntityInFrontOfCam()

        if (DoesEntityExist(entity)) then
            offsetCoords = GetOffsetFromEntityGivenWorldCoords(entity, GetCamCoord(cam))

            Citizen.Wait(1)
            local camCoords = GetCamCoord(cam)
            AttachCamToEntity(cam, entity, GetOffsetFromEntityInWorldCoords(entity, camCoords.x, camCoords.y, camCoords.z), true)

            isAttached = true
        end
    else
        ClearFocus()

        DetachCam(cam)

        isAttached = false
    end

    NuiSync({ attached = isAttached })
end

function ApplyFilter(filterIndex)
    SetTimecycleModifier(Config.filterList[filterIndex])
    currFilter = filterIndex
end

function ChangeFilterIntensity(intensity)
    SetTimecycleModifier(Config.filterList[currFilter])
    SetTimecycleModifierStrength(intensity)
    currFilterIntensity = intensity
end

function ResetFilter()
    ClearTimecycleModifier()
    currFilter          = 1
    currFilterIntensity = 1.0

    NuiSync({ filter = 1, intensity = 1.0 })
end

-- capture the current scene (filters and all). Hides the panel + cursor for a
-- clean frame, asks the server to grab & upload via `screencapture`, then restores.
function TakeScreenshot()
    if (shooting) then return end
    if (not (Config.screenshot and Config.screenshot.enable ~= false)) then return end

    shooting = true

    -- hide the panel and drop the mouse cursor so neither ends up in the shot
    SendNUIMessage({ action = 'hideForShot' })
    SetNuiFocus(true, false)

    CreateThread(function()
        Wait(150)   -- let the UI hide actually render before the grab
        TriggerServerEvent('syntax_frames:server:screenshot')
    end)
end



--------------------------------------------------
---------------- NUI CALLBACKS -------------------
--------------------------------------------------

RegisterNUICallback('uiClose', function(_, cb)
    CloseCamMenu()
    cb('ok')
end)

RegisterNUICallback('setCamActive', function(data, cb)
    ToggleCam(data.value == true, GetGameplayCamFov())
    cb('ok')
end)

RegisterNUICallback('setPrecision', function(data, cb)
    ChangePrecision(tonumber(data.value) + 0.0)
    cb('ok')
end)

RegisterNUICallback('setSpeed', function(data, cb)
    speed = tonumber(data.value) + 0.0
    cb('ok')
end)

RegisterNUICallback('setFov', function(data, cb)
    if (cam and DoesCamExist(cam)) then
        SetCamFov(cam, tonumber(data.value) + 0.0)
    end
    cb('ok')
end)

RegisterNUICallback('setFilter', function(data, cb)
    ApplyFilter(math.floor(tonumber(data.value)))
    cb('ok')
end)

RegisterNUICallback('setIntensity', function(data, cb)
    ChangeFilterIntensity(tonumber(data.value) + 0.0)
    cb('ok')
end)

RegisterNUICallback('resetFilter', function(_, cb)
    ResetFilter()
    cb('ok')
end)

RegisterNUICallback('takeScreenshot', function(_, cb)
    cb('ok')
    TakeScreenshot()
end)

RegisterNUICallback('setShowMap', function(data, cb)
    ToggleUI(data.value == true)
    cb('ok')
end)

RegisterNUICallback('setFreeFly', function(data, cb)
    ToggleFreeFlyMode(data.value == true)
    cb('ok')
end)

RegisterNUICallback('setCharControl', function(data, cb)
    ToggleCharacterControl(data.value == true)
    cb('ok')
end)

RegisterNUICallback('toggleAttach', function(_, cb)
    if (cam and not Config.noMetaGaming) then
        ToggleAttachMode()
    end
    cb('ok')
end)

-- OrbitCam (only does anything when the OrbitCam resource is running)
RegisterNUICallback('setOrbit', function(data, cb)
    if (GetResourceState("OrbitCam") == "started") then
        if (data.value == true) then
            exports["OrbitCam"]:StartOrbitCam(Config.OrbitOffset, entity or PlayerPedId(), nil, nil, nil, not DoesEntityExist(entity) and currOrbitBone or nil)
            exports["OrbitCam"]:SetAutoOrbitSpeed(currOrbitSpeed, Config.OrbitControl)
        else
            exports["OrbitCam"]:EndOrbitCam()
        end
    end
    cb('ok')
end)

RegisterNUICallback('setOrbitSpeed', function(data, cb)
    if (GetResourceState("OrbitCam") == "started") then
        currOrbitSpeed = tonumber(data.value) + 0.0
        exports["OrbitCam"]:SetAutoOrbitSpeed(currOrbitSpeed, true)
    end
    cb('ok')
end)

RegisterNUICallback('setOrbitControls', function(data, cb)
    if (GetResourceState("OrbitCam") == "started") then
        orbitControlsEnabled = data.value == true
        exports["OrbitCam"]:SetAutoOrbitSpeed(currOrbitSpeed, not orbitControlsEnabled)
    end
    cb('ok')
end)

RegisterNUICallback('setOrbitBone', function(data, cb)
    if (GetResourceState("OrbitCam") == "started") then
        currOrbitBone = math.floor(tonumber(data.value))
        local ped = PlayerPedId()
        local boneIndex = GetEntityBoneIndexByName(ped, boneNames[currOrbitBone])
        exports["OrbitCam"]:UpdateCamPosition(Config.OrbitOffset, ped, nil, nil, boneIndex)
    end
    cb('ok')
end)



--------------------------------------------------
--------------- ITEM (ox_inventory) --------------
--------------------------------------------------

-- called by the 'camera' item (client.export = 'syntax_frames.useCamera' in ox_inventory/data/items.lua)
-- consume = 0 on the item, so using it never removes it
exports('useCamera', function()
    if (not Config.useItem) then return end

    if (Config.usePermissions and not whitelisted) then
        print("No permission to use this item!")
        return
    end

    if (menuOpen) then
        CloseCamMenu()
    else
        OpenCamMenu()
    end
end)


--------------------------------------------------
-------------------- COMMANDS --------------------
--------------------------------------------------

-- register command if specified in config
if (Config.useCommand) then
    RegisterCommand(Config.command, function(source, args, raw)
        if (not Config.usePermissions or (Config.usePermissions and whitelisted)) then
            -- toggle: the command now closes the panel too, matching the item binding
            if (menuOpen) then
                CloseCamMenu()
            else
                OpenCamMenu()
            end
        else
            print("No permission to use this command!")
        end
    end)
end


--------------------------------------------------
--------------------- EVENTS ---------------------
--------------------------------------------------
RegisterNetEvent('syntax_frames:client:receivePermissions')
AddEventHandler('syntax_frames:client:receivePermissions', function(isWhitelisted)
    whitelisted = isWhitelisted
end)

-- screenshot result from the server: restore the panel and notify the player
RegisterNetEvent('syntax_frames:client:screenshotResult')
AddEventHandler('syntax_frames:client:screenshotResult', function(ok, url, reason)
    shooting = false

    -- bring the panel + cursor back if the menu is still open
    if (menuOpen) then
        SendNUIMessage({ action = 'showAfterShot' })
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    end

    if (ok) then
        lib.notify({ title = 'Syntax Frames', description = 'Screenshot saved 📷', type = 'success' })
    else
        lib.notify({ title = 'Syntax Frames', description = 'Screenshot failed: ' .. tostring(reason or 'error'), type = 'error' })
    end
end)

-- drop NUI focus if the resource stops while the panel is open
AddEventHandler('onResourceStop', function(resourceName)
    if (resourceName == GetCurrentResourceName() and menuOpen) then
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end)
