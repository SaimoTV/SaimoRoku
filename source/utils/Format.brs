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
    ' roUrlTransfer cannot be created on the SceneGraph render thread.
    out = ""
    for i = 1 to Len(raw)
        ch = Mid(raw, i, 1)
        code = Asc(ch)
        alnum = (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
        if alnum or ch = "-" or ch = "_" or ch = "." or ch = "~" then
            out = out + ch
        else if code < 128 then
            out = out + "%" + HexByte(code)
        else if code <= 2047 then
            out = out + "%" + HexByte(192 + Int(code / 64)) + "%" + HexByte(128 + (code mod 64))
        else if code <= 65535 then
            out = out + "%" + HexByte(224 + Int(code / 4096)) + "%" + HexByte(128 + (Int(code / 64) mod 64)) + "%" + HexByte(128 + (code mod 64))
        else
            ' Fora do plano básico (emoji): 4 bytes em UTF-8.
            out = out + "%" + HexByte(240 + Int(code / 262144)) + "%" + HexByte(128 + (Int(code / 4096) mod 64)) + "%" + HexByte(128 + (Int(code / 64) mod 64)) + "%" + HexByte(128 + (code mod 64))
        end if
    end for
    return out
end function

function HexByte(n as Integer) as String
    digits = "0123456789ABCDEF"
    return Mid(digits, Int(n / 16) + 1, 1) + Mid(digits, (n mod 16) + 1, 1)
end function
