--------------------------------------------------
------- SYNTAX FRAMES — screenshot upload ----------
--------------------------------------------------
-- Captures the player's current scene (filters and all) via the `screencapture`
-- resource (which provides screenshot-basic) and posts it to a Discord webhook.
--
-- The webhook URL is read SERVER-SIDE from a convar so it never reaches clients.
-- Add this to your server.cfg (use `set`, NOT `setr`, to keep it private):
--     set syntax_frames:webhook "https://discord.com/api/webhooks/XXXX/YYYY"

local WEBHOOK = GetConvar("syntax_frames:webhook", "")

-- Pull the attachment URL out of Discord's reply (only returned with ?wait=true).
local function discordAttachmentUrl(data)
    if type(data) == "string" then
        local ok, decoded = pcall(json.decode, data)
        if ok then data = decoded end
    end
    if type(data) ~= "table" then return nil end
    local a = data.attachments
    if type(a) == "table" and type(a[1]) == "table" then return a[1].url end
    return nil
end

RegisterNetEvent("syntax_frames:server:screenshot", function()
    local src = source

    local done = false
    local function reply(ok, url, reason)
        if done then return end
        done = true
        TriggerClientEvent("syntax_frames:client:screenshotResult", src, ok, url, reason)
    end

    if GetResourceState("screencapture") ~= "started" then
        return reply(false, nil, "screencapture not running")
    end

    local url = WEBHOOK
    if url == "" or url:find("XXXX", 1, true) then
        return reply(false, nil, "webhook not configured")
    end

    -- Discord only returns the message (with the attachment URL) when ?wait=true.
    if not url:find("wait=", 1, true) then
        url = url .. (url:find("?", 1, true) and "&" or "?") .. "wait=true"
    end

    -- 'blob' → real multipart/form-data file upload, which Discord requires.
    local opts = { encoding = "jpg", formField = "files[0]", headers = {} }

    local ok, err = pcall(function()
        exports.screencapture:remoteUpload(src, url, opts, function(data)
            local imgUrl = discordAttachmentUrl(data)
            reply(imgUrl ~= nil, imgUrl, imgUrl and nil or "upload failed")
        end, "blob")
    end)
    if not ok then
        return reply(false, nil, "export error: " .. tostring(err))
    end

    -- Backstop: if the upload aborts, screencapture may never call back.
    SetTimeout(20000, function() reply(false, nil, "timeout") end)
end)
