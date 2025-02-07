--#region LOGGER
function IMP_STATS_Logger(name)
    local logger

    if LibDebugLogger then
        logger = LibDebugLogger:Create(name or 'IMP_STATS')
        logger:SetMinLevelOverride(LibDebugLogger.LOG_LEVEL_DEBUG)
    end

    local level = LibDebugLogger.LOG_LEVEL_DEBUG
    local function inner (...)
        if logger then
            logger:Log(level, ...)
        end
    end

    return inner
end
--#endregion LOGGER