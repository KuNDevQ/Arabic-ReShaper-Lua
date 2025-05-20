--[[
    Arabic ReShaper
    Version: 1.0.0
    Description: Arabic ReShaper Lua is a lightweight and efficient Lua library for shaping Arabic text. 
        It handles contextual character linking (initial, medial, final, isolated forms) 
        and properly renders ligatures such as Lam-Alef. 
        The library also supports mixed text containing both Arabic and non-Arabic characters 
        by preserving their direction and structure.
        Ideal for use in game engines, custom UI systems, or rendering engines 
        where proper Arabic text shaping is not natively supported.
    GitHub: https://github.com/KuNDevQ/Arabic-ReShaper-Lua
    Author: Abdulmalik
--]]

ArabicReShaper = {}
ArabicReShaper.__index = ArabicReShaper
ArabicReShaper._VERSION = "1.0.0"

-- Constants for shaping forms
local ISOLATED, FINAL, INITIAL, MEDIAL = 0, 1, 2, 3
local NONE, BEFORE, DUAL, CAUSING = 0, 1, 2, 3
local LAM_CHAR = "ل"

-- Range and linking data
local start_char, end_char = "ء", "ي"
local start_codepoint, end_codepoint = utf8.codepoint(start_char), utf8.codepoint(end_char)

-- Map of pre-shaped Arabic characters
local LINK_MAP = {}
local LINK_MAP_STR = "ﺀﺁﺃﺅﺇﺉﺍﺏﺓﺕﺙﺝﺡﺥﺩﺫﺭﺯﺱﺵﺹﺽﻁﻅﻉﻍػؼؽؾؿـﻑﻕﻙﻝﻡﻥﻩﻭﻯﻱ"
for _, cp in utf8.codes(LINK_MAP_STR) do
    table.insert(LINK_MAP, utf8.char(cp))
end

local CHAR_LINK_TYPE = {
    NONE, BEFORE, BEFORE, BEFORE, BEFORE, DUAL, BEFORE, DUAL, BEFORE, DUAL,
    DUAL, DUAL, DUAL, DUAL, BEFORE, BEFORE, BEFORE, BEFORE, DUAL, DUAL,
    DUAL, DUAL, DUAL, DUAL, DUAL, DUAL, NONE, NONE, NONE, NONE,
    NONE, CAUSING, DUAL, DUAL, DUAL, DUAL, DUAL, DUAL, DUAL, BEFORE,
    DUAL, DUAL
}

-- Special Lam-Alef combinations
local lam_alef_bases = {
    ["آ"] = 0xFEF5,
    ["أ"] = 0xFEF7,
    ["إ"] = 0xFEF9,
    ["ا"] = 0xFEFB
}

-- Helper Functions
local function toCharArray(s)
    local chars = {}
    for _, cp in utf8.codes(s) do
        table.insert(chars, utf8.char(cp))
    end
    return chars
end

local function reverseString(s)
    local chars = toCharArray(s)
    local reversed = {}
    for i = #chars, 1, -1 do
        table.insert(reversed, chars[i])
    end
    return table.concat(reversed)
end

local function bor(a, b)
    local result, bit = 0, 1
    while a > 0 or b > 0 do
        if (a % 2 + b % 2) > 0 then
            result = result + bit
        end
        a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
    end
    return result
end

local function isCombining(char)
    local cp = utf8.codepoint(char)
    return cp >= 0x064B and cp <= 0x065E
end

local function isLinkableBefore(char)
    if not char or #char == 0 then return false end
    local cp = utf8.codepoint(char)
    if cp < start_codepoint or cp > end_codepoint then return false end
    local index = cp - start_codepoint
    local link_type = CHAR_LINK_TYPE[index + 1]
    return link_type == BEFORE or link_type == DUAL or link_type == CAUSING
end

local function isLinkableAfter(char)
    local cp = utf8.codepoint(char)
    if cp < start_codepoint or cp > end_codepoint then return false end
    local index = cp - start_codepoint
    local link_type = CHAR_LINK_TYPE[index + 1]
    return link_type == DUAL or link_type == CAUSING
end

local function linkLamAlef(nextChar, form)
    local base = lam_alef_bases[nextChar]
    if not base then return nextChar end
    local adjusted = (form == FINAL or form == MEDIAL) and 1 or 0
    return utf8.char(base + adjusted)
end

local function linkChar(char, form)
    local cp = utf8.codepoint(char)
    if cp < start_codepoint or cp > end_codepoint then return char end
    local index = cp - start_codepoint
    local link_type = CHAR_LINK_TYPE[index + 1]
    local base_char = LINK_MAP[index + 1]
    if not base_char then return char end
    local base_cp = utf8.codepoint(base_char)
    if link_type == BEFORE then
        return utf8.char(base_cp + (form % 2))
    elseif link_type == DUAL then
        return utf8.char(base_cp + form)
    elseif link_type == NONE then
        return base_char
    else
        return char
    end
end

local function internalLinkText(chars)
    local resultIndex, prevForm, i = 1, ISOLATED, 1
    while i <= #chars do
        local char = chars[i]
        local nextIndex = i + 1
        while nextIndex <= #chars and isCombining(chars[nextIndex]) do
            nextIndex = nextIndex + 1
        end
        local form = (prevForm == INITIAL or prevForm == MEDIAL) and FINAL or ISOLATED
        if nextIndex <= #chars then
            local nextChar = chars[nextIndex]
            if char == LAM_CHAR and lam_alef_bases[nextChar] then
                chars[resultIndex] = linkLamAlef(nextChar, form)
                resultIndex, i, prevForm = resultIndex + 1, nextIndex + 1, form
            else
                if isLinkableAfter(char) and isLinkableBefore(nextChar) then
                    form = bor(form, INITIAL)
                end
                chars[resultIndex] = linkChar(char, form)
                resultIndex, i, prevForm = resultIndex + 1, i + 1, form
            end
        else
            chars[resultIndex] = linkChar(char, form)
            resultIndex, i, prevForm = resultIndex + 1, i + 1, form
        end
    end
    return table.move(chars, 1, resultIndex - 1, 1, {})
end

local function isArabicChar(char)
    local cp = utf8.codepoint(char)
    return (cp >= start_codepoint and cp <= end_codepoint) or (cp >= 0x064B and cp <= 0x065E)
end

-- Public API
function ArabicReShaper.convertArabicText(text)
    if not text or #text == 0 then return "" end
    local chars = toCharArray(text)
    local linked = internalLinkText(chars)
    return reverseString(table.concat(linked))
end

function ArabicReShaper.convertMixedText(text)
    if not text or #text == 0 then return "" end
    local segments = {}
    local segment, currentArabic = {}, nil
    for _, char in ipairs(toCharArray(text)) do
        local isArabic = isArabicChar(char)
        if currentArabic == nil then
            currentArabic = isArabic
        end
        if isArabic == currentArabic then
            table.insert(segment, char)
        else
            local segStr = table.concat(segment)
            if currentArabic then
                segStr = ArabicReShaper.convertArabicText(segStr)
            end
            table.insert(segments, {text = segStr, isArabic = currentArabic})
            segment = {char}
            currentArabic = isArabic
        end
    end
    if #segment > 0 then
        local segStr = table.concat(segment)
        if currentArabic then
            segStr = ArabicReShaper.convertArabicText(segStr)
        end
        table.insert(segments, {text = segStr, isArabic = currentArabic})
    end
    local final = {}
    for i = #segments, 1, -1 do
        local seg = segments[i]
        if #final > 0 then
            local prev = final[#final]
            if not prev.text:match(" $") and not seg.text:match("^ ") then
                table.insert(final, {text = " ", isArabic = false})
            end
        end
        table.insert(final, seg)
    end
    local output = {}
    for _, seg in ipairs(final) do
        table.insert(output, seg.text)
    end
    return table.concat(output)
end

return ArabicReShaper
