--// This script nor its depdencies will never be obfuscated by me, it's all open source. \\--
local PlaceId = game.PlaceId

local MainRepository = "https://raw.githubusercontent.com/xaliatile/OPWScript/refs/heads/main/Games"
local GitSuccess, Repository = pcall(function(...)
    return game:HttpGet(`{MainRepository}/{PlaceId}.lua`)
end)

if GitSuccess and Repository then
    print(
        "[__bootstrapper]: Found potentially supported game!"
    )

    local Callback, Result = loadstring(Repository)

    if typeof(Callback) == "function" then
        Success, Result = pcall(Callback)

        if not Success then
            warn(
                `[__bootstrapper]: Failed to run callback, {Result}`
            )
        end
    else
        warn(
            `[__bootstrapper]: Failed to get callback from repository or callback isnt a valid function, {Result}`
        )
    end
else
    warn(
        `[__bootstrapper]: Failed to get repository, either not supported or an error occured whilst doing so.`
    )
end
