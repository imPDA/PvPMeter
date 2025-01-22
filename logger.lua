--#region LOGGER
local logger

if LibDebugLogger then
    logger = LibDebugLogger:Create('IPM')
    logger:SetMinLevelOverride(LibDebugLogger.LOG_LEVEL_DEBUG)
end

function IPM_Log(...)
    local level = LibDebugLogger.LOG_LEVEL_DEBUG
    if logger then
        logger:Log(level, ...)
    end
end
--#endregion LOGGER