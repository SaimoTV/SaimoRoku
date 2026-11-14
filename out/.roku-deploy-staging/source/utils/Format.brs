' ====================================================================
' Saimo TV - Format Helpers (BrightScript)
' ====================================================================

function FormatSecondsToTime(seconds as Integer) as String
    if seconds < 0 then seconds = 0
    hrs = Int(seconds / 3600)
    mins = Int((seconds mod 3600) / 60)
    secs = seconds mod 60

    minStr = mins.ToStr()
    if mins < 10 then minStr = "0" + minStr
    secStr = secs.ToStr()
    if secs < 10 then secStr = "0" + secStr

    if hrs > 0 then
        hrStr = hrs.ToStr()
        return hrStr + ":" + minStr + ":" + secStr
    else
        return minStr + ":" + secStr
    end if
end function

function CleanString(str as Dynamic) as String
    if str = invalid then return ""
    return str.ToStr().Trim()
end function

function StringEndsWith(str as String, suffix as String) as Boolean
    if Len(suffix) > Len(str) then return false
    return Right(str, Len(suffix)) = suffix
end function

function StringStartsWith(str as String, prefix as String) as Boolean
    if Len(prefix) > Len(str) then return false
    return Left(str, Len(prefix)) = prefix
end function

function UrlEncode(raw as String) as String
    ut = CreateObject("roUrlTransfer")
    return ut.Escape(raw)
end function
