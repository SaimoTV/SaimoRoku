' ====================================================================
' Saimo TV - Pure BrightScript QR Code Generator (ISO/IEC 18004)
' Suporta Byte mode (UTF-8/ASCII) para Versões 1..6 em nível M (até 106 bytes).
' Ideal para URLs locais como http://192.168.x.x:8999/addons.
' Sem dependências externas; 100% BrightScript puro.
' ====================================================================

function QrXor(a as Integer, b as Integer) as Integer
    return (a or b) and not (a and b)
end function

function QrBit(val as Integer, bitIdx as Integer) as Integer
    p = 1
    for i = 1 to bitIdx
        p = p * 2
    end for
    if Int(val / p) mod 2 = 1 then return 1
    return 0
end function

function QrBuildGfTables() as Object
    expTbl = CreateObject("roArray", 512, false)
    logTbl = CreateObject("roArray", 256, false)
    for i = 0 to 255
        logTbl[i] = 0
    end for
    x = 1
    for i = 0 to 254
        expTbl[i] = x
        expTbl[i + 255] = x
        logTbl[x] = i
        x = x * 2
        if x >= 256 then x = QrXor(x, 285) ' 0x11D
    end for
    expTbl[510] = expTbl[0]
    return { exp: expTbl, log: logTbl }
end function

function QrGfMul(a as Integer, b as Integer, gf as Object) as Integer
    if a = 0 or b = 0 then return 0
    return gf.exp[gf.log[a] + gf.log[b]]
end function

function QrRsGeneratorPoly(ecLen as Integer, gf as Object) as Object
    poly = [1]
    for i = 0 to ecLen - 1
        nextPoly = CreateObject("roArray", poly.Count() + 1, false)
        for k = 0 to poly.Count()
            nextPoly[k] = 0
        end for
        factor = gf.exp[i]
        for j = 0 to poly.Count() - 1
            nextPoly[j] = QrXor(nextPoly[j], poly[j])
            nextPoly[j + 1] = QrXor(nextPoly[j + 1], QrGfMul(poly[j], factor, gf))
        end for
        poly = nextPoly
    end for
    return poly
end function

function QrRsCompute(data as Object, ecLen as Integer, gf as Object) as Object
    gen = QrRsGeneratorPoly(ecLen, gf)
    res = CreateObject("roArray", data.Count() + ecLen, false)
    for i = 0 to data.Count() - 1
        res[i] = data[i]
    end for
    for i = data.Count() to data.Count() + ecLen - 1
        res[i] = 0
    end for

    for i = 0 to data.Count() - 1
        coef = res[i]
        if coef <> 0 then
            for j = 0 to gen.Count() - 1
                res[i + j] = QrXor(res[i + j], QrGfMul(gen[j], coef, gf))
            end for
        end if
    end for

    ec = []
    for i = data.Count() to res.Count() - 1
        ec.Push(res[i])
    end for
    return ec
end function

function QrVersionSpecsM() as Object
    ' { ver, size, dataCodewords, blocks, blockData, ecPerBlock, maxBytes, align }
    return [
        { ver: 1, size: 21, dataCw: 16, blocks: 1, blockData: 16, ecPerBlock: 10, maxBytes: 14, align: [] },
        { ver: 2, size: 25, dataCw: 28, blocks: 1, blockData: 28, ecPerBlock: 16, maxBytes: 26, align: [6, 18] },
        { ver: 3, size: 29, dataCw: 44, blocks: 1, blockData: 44, ecPerBlock: 26, maxBytes: 42, align: [6, 22] },
        { ver: 4, size: 33, dataCw: 64, blocks: 2, blockData: 32, ecPerBlock: 18, maxBytes: 62, align: [6, 26] },
        { ver: 5, size: 37, dataCw: 86, blocks: 2, blockData: 43, ecPerBlock: 24, maxBytes: 84, align: [6, 30] },
        { ver: 6, size: 41, dataCw: 108, blocks: 4, blockData: 27, ecPerBlock: 16, maxBytes: 106, align: [6, 34] }
    ]
end function

sub QrPushBits(bits as Object, val as Integer, count as Integer)
    for i = count - 1 to 0 step -1
        bits.Push(QrBit(val, i))
    end for
end sub

sub QrPlaceFinder(modules as Object, reserved as Object, size as Integer, topRow as Integer, leftCol as Integer)
    for r = -1 to 7
        rr = topRow + r
        if rr >= 0 and rr < size then
            for c = -1 to 7
                cc = leftCol + c
                if cc >= 0 and cc < size then
                    dark = 0
                    if r >= 0 and r <= 6 and c >= 0 and c <= 6 then
                        if r = 0 or r = 6 or c = 0 or c = 6 or (r >= 2 and r <= 4 and c >= 2 and c <= 4) then
                            dark = 1
                        end if
                    end if
                    modules[rr][cc] = dark
                    reserved[rr][cc] = true
                end if
            end for
        end if
    end for
end sub

sub QrPlaceAlignment(modules as Object, reserved as Object, centerR as Integer, centerC as Integer)
    for r = -2 to 2
        for c = -2 to 2
            rr = centerR + r
            cc = centerC + c
            dark = 0
            if r = -2 or r = 2 or c = -2 or c = 2 or (r = 0 and c = 0) then dark = 1
            modules[rr][cc] = dark
            reserved[rr][cc] = true
        end for
    end for
end sub

function QrFormatWordM(maskIdx as Integer) as Integer
    ' EC Level M = 00 -> data5 = maskIdx (0..7)
    ' BCH(15, 5) com gerador 0x537, XOR final com 0x5412
    dataBits = maskIdx * 1024
    remBits = dataBits
    for i = 14 to 10 step -1
        if QrBit(remBits, i) = 1 then
            shiftedGen = 1335 ' 0x537
            for s = 1 to i - 10
                shiftedGen = shiftedGen * 2
            end for
            remBits = QrXor(remBits, shiftedGen)
        end if
    end for
    rawWord = dataBits + remBits
    return QrXor(rawWord, 21522) ' 0x5412
end function

sub QrApplyFormat(modules as Object, size as Integer, maskIdx as Integer)
    fmt = QrFormatWordM(maskIdx)
    for i = 0 to 14
        bitVal = QrBit(fmt, i)
        ' Cópia 1 (ao redor do finder superior esquerdo: bit 14 em (8,0) até bit 0 em (0,8))
        if i <= 5 then
            modules[i][8] = bitVal
        else if i <= 7 then
            modules[i + 1][8] = bitVal
        else if i = 8 then
            modules[8][7] = bitVal
        else
            modules[8][14 - i] = bitVal
        end if

        ' Cópia 2 (superior direito bits 0..7 em (8, size-1..size-8), inferior esquerdo bits 8..14 em (size-7..size-1, 8))
        if i <= 7 then
            modules[8][size - 1 - i] = bitVal
        else
            modules[size - 15 + i][8] = bitVal
        end if
    end for
end sub

function QrMaskCondition(maskIdx as Integer, r as Integer, c as Integer) as Boolean
    if maskIdx = 0 then return ((r + c) mod 2) = 0
    if maskIdx = 1 then return (r mod 2) = 0
    if maskIdx = 2 then return (c mod 3) = 0
    if maskIdx = 3 then return ((r + c) mod 3) = 0
    if maskIdx = 4 then return ((Int(r / 2) + Int(c / 3)) mod 2) = 0
    if maskIdx = 5 then return (((r * c) mod 2) + ((r * c) mod 3)) = 0
    if maskIdx = 6 then return ((((r * c) mod 2) + ((r * c) mod 3)) mod 2) = 0
    if maskIdx = 7 then return ((((r + c) mod 2) + ((r * c) mod 3)) mod 2) = 0
    return false
end function

function QrCloneGrid(grid as Object, size as Integer) as Object
    copy = CreateObject("roArray", size, false)
    for r = 0 to size - 1
        row = CreateObject("roArray", size, false)
        src = grid[r]
        for c = 0 to size - 1
            row[c] = src[c]
        end for
        copy[r] = row
    end for
    return copy
end function

function QrEvalPenalty(grid as Object, size as Integer) as Integer
    penalty = 0

    ' Regra 1: 5 ou mais módulos iguais em linha/coluna
    for r = 0 to size - 1
        row = grid[r]
        runVal = row[0]
        runLen = 1
        for c = 1 to size - 1
            if row[c] = runVal then
                runLen = runLen + 1
            else
                if runLen >= 5 then penalty = penalty + 3 + (runLen - 5)
                runVal = row[c]
                runLen = 1
            end if
        end for
        if runLen >= 5 then penalty = penalty + 3 + (runLen - 5)
    end for

    for c = 0 to size - 1
        runVal = grid[0][c]
        runLen = 1
        for r = 1 to size - 1
            if grid[r][c] = runVal then
                runLen = runLen + 1
            else
                if runLen >= 5 then penalty = penalty + 3 + (runLen - 5)
                runVal = grid[r][c]
                runLen = 1
            end if
        end for
        if runLen >= 5 then penalty = penalty + 3 + (runLen - 5)
    end for

    ' Regra 2: blocos 2x2 da mesma cor
    for r = 0 to size - 2
        r0 = grid[r]
        r1 = grid[r + 1]
        for c = 0 to size - 2
            v = r0[c]
            if r0[c + 1] = v and r1[c] = v and r1[c + 1] = v then
                penalty = penalty + 3
            end if
        end for
    end for

    ' Regra 3: padrão 1:1:3:1:1 + 4 zeros (aproximação rápida)
    for r = 0 to size - 1
        row = grid[r]
        for c = 0 to size - 11
            if row[c] = 1 and row[c+1] = 0 and row[c+2] = 1 and row[c+3] = 1 and row[c+4] = 1 and row[c+5] = 0 and row[c+6] = 1 then
                if row[c+7] = 0 and row[c+8] = 0 and row[c+9] = 0 and row[c+10] = 0 then penalty = penalty + 40
            end if
            if row[c] = 0 and row[c+1] = 0 and row[c+2] = 0 and row[c+3] = 0 and row[c+4] = 1 and row[c+5] = 0 and row[c+6] = 1 and row[c+7] = 1 and row[c+8] = 1 and row[c+9] = 0 and row[c+10] = 1 then
                penalty = penalty + 40
            end if
        end for
    end for

    for c = 0 to size - 1
        for r = 0 to size - 11
            if grid[r][c] = 1 and grid[r+1][c] = 0 and grid[r+2][c] = 1 and grid[r+3][c] = 1 and grid[r+4][c] = 1 and grid[r+5][c] = 0 and grid[r+6][c] = 1 then
                if grid[r+7][c] = 0 and grid[r+8][c] = 0 and grid[r+9][c] = 0 and grid[r+10][c] = 0 then penalty = penalty + 40
            end if
            if grid[r][c] = 0 and grid[r+1][c] = 0 and grid[r+2][c] = 0 and grid[r+3][c] = 0 and grid[r+4][c] = 1 and grid[r+5][c] = 0 and grid[r+6][c] = 1 and grid[r+7][c] = 1 and grid[r+8][c] = 1 and grid[r+9][c] = 0 and grid[r+10][c] = 1 then
                penalty = penalty + 40
            end if
        end for
    end for

    ' Regra 4: proporção de módulos escuros
    darkCount = 0
    for r = 0 to size - 1
        for c = 0 to size - 1
            if grid[r][c] = 1 then darkCount = darkCount + 1
        end for
    end for
    total = size * size
    pct = Int((darkCount * 100) / total)
    prev5 = Int(pct / 5) * 5
    next5 = prev5 + 5
    d1 = Abs(prev5 - 50) / 5
    d2 = Abs(next5 - 50) / 5
    if d1 < d2 then
        penalty = penalty + Int(d1) * 10
    else
        penalty = penalty + Int(d2) * 10
    end if

    return penalty
end function

function QrEncodeMatrix(text as String) as Dynamic
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(text)
    byteLen = ba.Count()

    spec = invalid
    for each candidate in QrVersionSpecsM()
        if byteLen <= candidate.maxBytes then
            spec = candidate
            exit for
        end if
    end for
    if spec = invalid then return invalid

    ' 1. Fluxo de bits (Byte Mode 0100 + count 8 bits + dados + terminador + padding)
    bits = []
    QrPushBits(bits, 4, 4)
    QrPushBits(bits, byteLen, 8)
    for i = 0 to byteLen - 1
        QrPushBits(bits, ba[i], 8)
    end for

    totalDataBits = spec.dataCw * 8
    termLen = 4
    if totalDataBits - bits.Count() < termLen then termLen = totalDataBits - bits.Count()
    for i = 1 to termLen
        bits.Push(0)
    end for
    while (bits.Count() mod 8) <> 0
        bits.Push(0)
    end while

    padBytes = [236, 17] ' 0xEC, 0x11
    padIdx = 0
    while bits.Count() < totalDataBits
        QrPushBits(bits, padBytes[padIdx], 8)
        padIdx = (padIdx + 1) mod 2
    end while

    dataCodewords = []
    for i = 0 to bits.Count() - 1 step 8
        valByte = 0
        for b = 0 to 7
            valByte = valByte * 2 + bits[i + b]
        end for
        dataCodewords.Push(valByte)
    end for

    ' 2. Blocos Reed-Solomon + Interleaving
    gf = QrBuildGfTables()
    dataBlocks = []
    ecBlocks = []
    offset = 0
    for b = 0 to spec.blocks - 1
        blk = []
        for i = 0 to spec.blockData - 1
            blk.Push(dataCodewords[offset + i])
        end for
        offset = offset + spec.blockData
        dataBlocks.Push(blk)
        ecBlocks.Push(QrRsCompute(blk, spec.ecPerBlock, gf))
    end for

    finalCodewords = []
    for i = 0 to spec.blockData - 1
        for b = 0 to spec.blocks - 1
            finalCodewords.Push(dataBlocks[b][i])
        end for
    end for
    for i = 0 to spec.ecPerBlock - 1
        for b = 0 to spec.blocks - 1
            finalCodewords.Push(ecBlocks[b][i])
        end for
    end for

    finalBits = []
    for each cw in finalCodewords
        QrPushBits(finalBits, cw, 8)
    end for
    ' Remainder bits (7 bits para V2..V6; 0 para V1)
    remBitsCount = 0
    if spec.ver >= 2 and spec.ver <= 6 then remBitsCount = 7
    for i = 1 to remBitsCount
        finalBits.Push(0)
    end for

    ' 3. Matriz base com padrões funcionais
    size = spec.size
    modules = CreateObject("roArray", size, false)
    reserved = CreateObject("roArray", size, false)
    for r = 0 to size - 1
        mRow = CreateObject("roArray", size, false)
        rRow = CreateObject("roArray", size, false)
        for c = 0 to size - 1
            mRow[c] = 0
            rRow[c] = false
        end for
        modules[r] = mRow
        reserved[r] = rRow
    end for

    QrPlaceFinder(modules, reserved, size, 0, 0)
    QrPlaceFinder(modules, reserved, size, 0, size - 7)
    QrPlaceFinder(modules, reserved, size, size - 7, 0)

    if spec.align.Count() > 0 then
        for each ar in spec.align
            for each ac in spec.align
                if not reserved[ar][ac] then
                    QrPlaceAlignment(modules, reserved, ar, ac)
                end if
            end for
        end for
    end if

    ' Timing patterns (linha 6 e coluna 6)
    for i = 8 to size - 9
        bitVal = 0
        if (i mod 2) = 0 then bitVal = 1
        if not reserved[6][i] then
            modules[6][i] = bitVal
            reserved[6][i] = true
        end if
        if not reserved[i][6] then
            modules[i][6] = bitVal
            reserved[i][6] = true
        end if
    end for

    ' Dark module fixo em (4*ver + 9, 8)
    modules[4 * spec.ver + 9][8] = 1
    reserved[4 * spec.ver + 9][8] = true

    ' Reserva áreas de Format Information
    for i = 0 to 8
        if i <> 6 then
            reserved[8][i] = true
            reserved[i][8] = true
        end if
    end for
    for i = size - 8 to size - 1
        reserved[8][i] = true
        reserved[i][8] = true
    end for

    ' 4. Posicionamento dos bits em zigue-zague
    bitIdx = 0
    upward = true
    col = size - 1
    while col >= 1
        if col = 6 then col = 5
        for stepIdx = 0 to size - 1
            r = stepIdx
            if upward then r = size - 1 - stepIdx
            for dc = 0 to 1
                cc = col - dc
                if not reserved[r][cc] then
                    v = 0
                    if bitIdx < finalBits.Count() then
                        v = finalBits[bitIdx]
                        bitIdx = bitIdx + 1
                    end if
                    modules[r][cc] = v
                end if
            end for
        end for
        upward = not upward
        col = col - 2
    end while

    ' 5. Escolhe a melhor máscara (0..7)
    bestGrid = invalid
    bestPenalty = 999999999
    for maskIdx = 0 to 7
        cand = QrCloneGrid(modules, size)
        for r = 0 to size - 1
            for c = 0 to size - 1
                if not reserved[r][c] and QrMaskCondition(maskIdx, r, c) then
                    if cand[r][c] = 1 then cand[r][c] = 0 else cand[r][c] = 1
                end if
            end for
        end for
        QrApplyFormat(cand, size, maskIdx)
        p = QrEvalPenalty(cand, size)
        if p < bestPenalty then
            bestPenalty = p
            bestGrid = cand
        end if
    end for

    return { size: size, version: spec.ver, modules: bestGrid }
end function

sub QrRenderToGroup(container as Object, qrText as String, totalSizePx as Integer)
    if container = invalid then return
    while container.getChildCount() > 0
        container.removeChildIndex(0)
    end while

    bg = container.createChild("Rectangle")
    bg.width = totalSizePx
    bg.height = totalSizePx
    bg.color = "#FFFFFF"

    qr = QrEncodeMatrix(qrText)
    if qr = invalid or qr.modules = invalid then return

    quietModules = 4
    gridModules = qr.size + quietModules * 2
    modSize = Int(totalSizePx / gridModules)
    if modSize < 2 then modSize = 2
    usedPx = modSize * gridModules
    offsetPx = Int((totalSizePx - usedPx) / 2)

    ' Mescla módulos horizontais consecutivos para renderizar rápido no Roku
    for r = 0 to qr.size - 1
        row = qr.modules[r]
        c = 0
        while c < qr.size
            if row[c] = 1 then
                runStart = c
                while c < qr.size and row[c] = 1
                    c = c + 1
                end while
                rect = container.createChild("Rectangle")
                rect.translation = [offsetPx + (runStart + quietModules) * modSize, offsetPx + (r + quietModules) * modSize]
                rect.width = (c - runStart) * modSize
                rect.height = modSize
                rect.color = "#0B0E14"
            else
                c = c + 1
            end if
        end while
    end for
end sub
