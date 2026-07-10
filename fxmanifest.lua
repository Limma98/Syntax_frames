--------------------------------------------------
------- SYNTAX FRAMES — cinematic camera ----------
--------------------------------------------------
-- Originally "Cinematic Cam" by kiminaze (Philipp Decker); reworked for Syntax.

fx_version "cerulean"
games { "gta5" }

author "Syntax Development"
description "Cinematic camera"
version "1.3.0"

shared_scripts {
	"@ox_lib/init.lua"
}

server_scripts {
	"server/permission.lua",
	"server/screenshot.lua"
}

client_scripts {
	"client/language.lua",
	"client/boneSelects.lua",
	"localization/*.lua",
	"config.lua",
	"client/cameraFilter.lua",
	"client/client.lua"
}

ui_page "html/index.html"

files {
	"html/index.html",
	"html/style.css",
	"html/script.js"
}



