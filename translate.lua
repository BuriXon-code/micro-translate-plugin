--[[
translate.lua
Author: Kamil BuriXon Burek
Version: 1.0.0
Year: 2026

Description:
	An easy-to-use plugin for the micro text editor that uses the public
	Google Translator endpoint to translate selected text into other languages.
	To function properly, the plugin needs access to the curl command, which
	allows it to send and receive data from the endpoint.

Usage:
	translate [-t LANG] [-s LANG] [-f SECONDS]

License:
	MIT License
	This script is licensed under the MIT License.
	You are free to use, modify, and distribute it.
--]]

VERSION = "1.0.0"

local config = import("micro/config")
local micro = import("micro")
local buffer = import("micro/buffer")

local PLUGIN_NAME = "translate"
local TRANSLATE_URL = "https://translate.googleapis.com/translate_a/single"

local supportedLangs = {
	af = "Afrikaans",
	sq = "Albanian",
	am = "Amharic",
	ar = "Arabic",
	hy = "Armenian",
	az = "Azerbaijani",
	eu = "Basque",
	be = "Belarusian",
	bn = "Bengali",
	bs = "Bosnian",
	bg = "Bulgarian",
	ca = "Catalan",
	ceb = "Cebuano",
	ny = "Chichewa",
	zh = "Chinese",
	zhCN = "Chinese (Simplified)",
	zhTW = "Chinese (Traditional)",
	co = "Corsican",
	hr = "Croatian",
	cs = "Czech",
	da = "Danish",
	nl = "Dutch",
	en = "English",
	eo = "Esperanto",
	et = "Estonian",
	tl = "Filipino",
	fi = "Finnish",
	fr = "French",
	fy = "Frisian",
	ga = "Irish",
	gl = "Galician",
	ka = "Georgian",
	de = "German",
	el = "Greek",
	gu = "Gujarati",
	ht = "Haitian Creole",
	ha = "Hausa",
	haw = "Hawaiian",
	he = "Hebrew",
	hi = "Hindi",
	hmn = "Hmong",
	hu = "Hungarian",
	is = "Icelandic",
	ig = "Igbo",
	id = "Indonesian",
	ga_IE = "Irish",
	it = "Italian",
	ja = "Japanese",
	jw = "Javanese",
	kn = "Kannada",
	kk = "Kazakh",
	km = "Khmer",
	ko = "Korean",
	ku = "Kurdish",
	ky = "Kyrgyz",
	lo = "Lao",
	la = "Latin",
	lv = "Latvian",
	lt = "Lithuanian",
	lb = "Luxembourgish",
	mk = "Macedonian",
	mg = "Malagasy",
	ms = "Malay",
	ml = "Malayalam",
	mt = "Maltese",
	mi = "Maori",
	mr = "Marathi",
	mn = "Mongolian",
	my = "Myanmar",
	ne = "Nepali",
	no = "Norwegian",
	or_ = "Odia",
	ps = "Pashto",
	fa = "Persian",
	pl = "Polish",
	pt = "Portuguese",
	pa = "Punjabi",
	ro = "Romanian",
	ru = "Russian",
	sm = "Samoan",
	gd = "Scots Gaelic",
	sr = "Serbian",
	st = "Sesotho",
	sn = "Shona",
	sd = "Sindhi",
	si = "Sinhala",
	sk = "Slovak",
	sl = "Slovenian",
	so = "Somali",
	es = "Spanish",
	su = "Sundanese",
	sw = "Swahili",
	sv = "Swedish",
	tg = "Tajik",
	ta = "Tamil",
	te = "Telugu",
	th = "Thai",
	tr = "Turkish",
	uk = "Ukrainian",
	ur = "Urdu",
	uz = "Uzbek",
	vi = "Vietnamese",
	cy = "Welsh",
	xh = "Xhosa",
	yi = "Yiddish",
	yo = "Yoruba",
	zu = "Zulu",
	auto = "Auto Detect",
}

local function safeString(s)
	if s == nil then
		return ""
	end
	if type(s) ~= "string" then
		return tostring(s)
	end
	return s
end

local function trim(s)
	s = safeString(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shellQuote(s)
	s = safeString(s)
	if s == "" then
		return "''"
	end
	return "'" .. s:gsub("'", [['"'"']]) .. "'"
end

local function info(msg)
	micro.InfoBar():Message("translate: " .. safeString(msg))
end

local function err(msg)
	micro.InfoBar():Error("translate: " .. safeString(msg))
end

local function usage()
	info("Usage: translate -t LANG [-s LANG] [-f timeout_seconds]")
end

local function commandExists(cmd)
	local p = io.popen("command -v " .. shellQuote(cmd) .. " >/dev/null 2>&1; echo $?", "r")
	if not p then
		return false
	end
	local out = p:read("*a") or ""
	p:close()
	return trim(out) == "0"
end

local function isSupportedLang(lang)
	lang = trim(safeString(lang))
	return supportedLangs[lang] ~= nil
end

local function getTextLoc(bp)
	if bp == nil or bp.Cursor == nil or bp.Buf == nil then
		return nil, nil
	end

	local c = bp.Cursor
	local b = bp.Buf

	if c:HasSelection() then
		local a = c.CurSelection[1]
		local d = c.CurSelection[2]

		if a.Y > d.Y or (a.Y == d.Y and a.X > d.X) then
			a, d = d, a
		end

		return buffer.Loc(a.X, a.Y), buffer.Loc(d.X, d.Y)
	end

	local y = c.Loc.Y
	local line = b:Line(y) or ""
	return buffer.Loc(0, y), buffer.Loc(#line, y)
end

local function getText(bp, a, b)
	local buf = bp.Buf

	if a == nil or b == nil then
		return ""
	end

	if a.Y == b.Y then
		local line = buf:Line(a.Y) or ""
		return line:sub(a.X + 1, b.X)
	end

	local txt = {}
	txt[#txt + 1] = (buf:Line(a.Y) or ""):sub(a.X + 1)

	for lineNo = a.Y + 1, b.Y - 1 do
		txt[#txt + 1] = buf:Line(lineNo) or ""
	end

	txt[#txt + 1] = (buf:Line(b.Y) or ""):sub(1, b.X)
	return table.concat(txt, "\n")
end

local function parseArgs(args)
	local opts = {
		source = "auto",
		target = nil,
		timeout = 10,
		showHelp = false,
	}

	local i = 1
	while i <= #args do
		local token = safeString(args[i])

		if token == "-s" or token == "--source" then
			local v = args[i + 1]
			if v ~= nil and safeString(v) ~= "" then
				opts.source = safeString(v)
				i = i + 1
			end

		elseif token == "-t" or token == "--target" then
			local v = args[i + 1]
			if v ~= nil and safeString(v) ~= "" then
				opts.target = safeString(v)
				i = i + 1
			end

		elseif token == "-f" or token == "--timeout" then
			local v = args[i + 1]
			if v ~= nil then
				local n = tonumber(safeString(v))
				if n and n > 0 then
					opts.timeout = n
				end
				i = i + 1
			end
		end

		i = i + 1
	end

	return opts
end

local function normalizeOutput(out)
	out = safeString(out):gsub("\r\n", "\n")
	if out:sub(-1) == "\n" then
		out = out:sub(1, -2)
	end
	return out
end

local function codepointToUtf8(cp)
	if cp <= 0x7F then
		return string.char(cp)
	elseif cp <= 0x7FF then
		return string.char(
			0xC0 + math.floor(cp / 0x40),
			0x80 + (cp % 0x40)
		)
	elseif cp <= 0xFFFF then
		return string.char(
			0xE0 + math.floor(cp / 0x1000),
			0x80 + math.floor((cp % 0x1000) / 0x40),
			0x80 + (cp % 0x40)
		)
	else
		return string.char(
			0xF0 + math.floor(cp / 0x40000),
			0x80 + math.floor((cp % 0x40000) / 0x1000),
			0x80 + math.floor((cp % 0x1000) / 0x40),
			0x80 + (cp % 0x40)
		)
	end
end

local function jsonDecode(str)
	local pos = 1
	local len = #str

	local function peek()
		if pos > len then
			return ""
		end
		return str:sub(pos, pos)
	end

	local function nextc()
		local c = peek()
		pos = pos + 1
		return c
	end

	local function skipWs()
		while true do
			local c = peek()
			if c == "" or not c:match("%s") then
				break
			end
			pos = pos + 1
		end
	end

	local parseValue

	local function parseString()
		if nextc() ~= '"' then
			return nil, "expected string"
		end

		local out = {}
		while true do
			local c = nextc()
			if c == "" then
				return nil, "unterminated string"
			elseif c == '"' then
				return table.concat(out)
			elseif c == "\\" then
				local e = nextc()
				if e == "" then
					return nil, "bad escape"
				elseif e == '"' or e == "\\" or e == "/" then
					out[#out + 1] = e
				elseif e == "b" then
					out[#out + 1] = "\b"
				elseif e == "f" then
					out[#out + 1] = "\f"
				elseif e == "n" then
					out[#out + 1] = "\n"
				elseif e == "r" then
					out[#out + 1] = "\r"
				elseif e == "t" then
					out[#out + 1] = "\t"
				elseif e == "u" then
					local hex = str:sub(pos, pos + 3)
					if #hex < 4 or not hex:match("^[0-9a-fA-F]+$") then
						return nil, "bad unicode escape"
					end
					pos = pos + 4
					local cp = tonumber(hex, 16)

					if cp >= 0xD800 and cp <= 0xDBFF then
						local savePos = pos
						if str:sub(pos, pos + 1) == "\\u" then
							pos = pos + 2
							local hex2 = str:sub(pos, pos + 3)
							if #hex2 == 4 and hex2:match("^[0-9a-fA-F]+$") then
								local cp2 = tonumber(hex2, 16)
								if cp2 >= 0xDC00 and cp2 <= 0xDFFF then
									pos = pos + 4
									cp = 0x10000 + ((cp - 0xD800) * 0x400) + (cp2 - 0xDC00)
								else
									pos = savePos
								end
							else
								pos = savePos
							end
						else
							pos = savePos
						end
					end

					out[#out + 1] = codepointToUtf8(cp)
				else
					return nil, "bad escape"
				end
			else
				out[#out + 1] = c
			end
		end
	end

	local function parseNumber()
		local start = pos
		local c = peek()
		if c == "-" then
			pos = pos + 1
		end
		while peek():match("%d") do
			pos = pos + 1
		end
		if peek() == "." then
			pos = pos + 1
			while peek():match("%d") do
				pos = pos + 1
			end
		end
		local e = peek()
		if e == "e" or e == "E" then
			pos = pos + 1
			local s = peek()
			if s == "+" or s == "-" then
				pos = pos + 1
			end
			while peek():match("%d") do
				pos = pos + 1
			end
		end
		return tonumber(str:sub(start, pos - 1))
	end

	local function parseArray()
		if nextc() ~= "[" then
			return nil, "expected array"
		end
		local arr = {}
		skipWs()
		if peek() == "]" then
			pos = pos + 1
			return arr
		end

		while true do
			skipWs()
			local v, e = parseValue()
			if e then
				return nil, e
			end
			arr[#arr + 1] = v
			skipWs()
			local c = nextc()
			if c == "]" then
				return arr
			elseif c ~= "," then
				return nil, "expected , or ]"
			end
		end
	end

	local function parseObject()
		if nextc() ~= "{" then
			return nil, "expected object"
		end
		local obj = {}
		skipWs()
		if peek() == "}" then
			pos = pos + 1
			return obj
		end

		while true do
			skipWs()
			local key, e = parseString()
			if e then
				return nil, e
			end
			skipWs()
			if nextc() ~= ":" then
				return nil, "expected :"
			end
			skipWs()
			local v, e2 = parseValue()
			if e2 then
				return nil, e2
			end
			obj[key] = v
			skipWs()
			local c = nextc()
			if c == "}" then
				return obj
			elseif c ~= "," then
				return nil, "expected , or }"
			end
		end
	end

	function parseValue()
		skipWs()
		local c = peek()
		if c == '"' then
			return parseString()
		elseif c == "[" then
			return parseArray()
		elseif c == "{" then
			return parseObject()
		elseif c == "-" or c:match("%d") then
			return parseNumber()
		elseif str:sub(pos, pos + 3) == "null" then
			pos = pos + 4
			return nil
		elseif str:sub(pos, pos + 3) == "true" then
			pos = pos + 4
			return true
		elseif str:sub(pos, pos + 4) == "false" then
			pos = pos + 5
			return false
		end
		return nil, "invalid endpoint response"
	end

	local v, e = parseValue()
	if e then
		return nil, e
	end
	return v
end

local function extractTranslation(decoded)
	if type(decoded) ~= "table" then
		return nil
	end

	local first = decoded[1]
	if type(first) ~= "table" then
		return nil
	end

	local out = {}

	for i = 1, #first do
		local seg = first[i]
		if type(seg) == "table" and type(seg[1]) == "string" then
			out[#out + 1] = seg[1]
		end
	end

	if #out == 0 then
		return nil
	end

	return table.concat(out)
end

local function shorten(s, n)
	s = safeString(s)
	n = n or 180
	if #s <= n then
		return s
	end
	return s:sub(1, n) .. "..."
end

local function buildCurlCommand(text, opts)
	local timeout = tostring(math.floor(tonumber(opts.timeout) or 10))
	return table.concat({
		"curl -fsS",
		" --connect-timeout " .. shellQuote(timeout),
		" --max-time " .. shellQuote(timeout),
		" --get",
		" --data-urlencode " .. shellQuote("client=gtx"),
		" --data-urlencode " .. shellQuote("dt=t"),
		" --data-urlencode " .. shellQuote("sl=" .. opts.source),
		" --data-urlencode " .. shellQuote("tl=" .. opts.target),
		" --data-urlencode " .. shellQuote("q=" .. text),
		" " .. shellQuote(TRANSLATE_URL),
		" 2>&1",
	}, "")
end

local function runTranslator(text, opts)
	if not isSupportedLang(opts.source) then
		return nil, "unsupported source language: " .. tostring(opts.source)
	end

	if not isSupportedLang(opts.target) then
		return nil, "unsupported target language: " .. tostring(opts.target)
	end

	local cmd = buildCurlCommand(text, opts)

	local handle, openErr = io.popen(cmd, "r")
	if not handle then
		return nil, "failed to start curl: " .. tostring(openErr)
	end

	local out = handle:read("*a") or ""
	local ok, how, code = handle:close()

	out = normalizeOutput(out)

	if not ok then
		local msg = "translate request failed"
		if trim(out) ~= "" then
			msg = msg .. ": " .. shorten(trim(out), 240)
		elseif how ~= nil then
			msg = msg .. ": " .. tostring(how)
		end
		if code ~= nil then
			msg = msg .. " (" .. tostring(code) .. ")"
		end
		return nil, msg
	end

	if trim(out) == "" then
		return nil, "empty endpoint response"
	end

	local decoded, jsonErr = jsonDecode(out)
	if decoded == nil then
		return nil, "error: " .. tostring(jsonErr)
	end

	local translated = extractTranslation(decoded)
	if translated == nil or trim(translated) == "" then
		return nil, "other unknown error"
	end

	return translated, nil
end

local function startTranslation(bp, opts)
	if not commandExists("curl") then
		err('command not found: "curl"')
		return
	end

	if opts.target == nil or trim(opts.target) == "" then
		err("missing -t LANG")
		usage()
		return
	end

	local a, b = getTextLoc(bp)
	if a == nil or b == nil then
		err("no buffer available")
		return
	end

	local text = getText(bp, a, b)
	if trim(text) == "" then
		err("nothing to translate")
		return
	end

	info("Translation...")

	local out, runErr = runTranslator(text, opts)
	if runErr ~= nil then
		err(runErr)
		return
	end

	out = safeString(out)
	if trim(out) == "" then
		err("translation returned empty output")
		return
	end

	local okReplace, replaceErr = pcall(function()
		bp.Buf:Replace(a, b, out)
	end)

	if not okReplace then
		err("insert failed: " .. tostring(replaceErr))
		return
	end

	info("done")
end

local function translate(bp, args)
	local opts = parseArgs(args)

	if opts.showHelp then
		usage()
		return
	end

	startTranslation(bp, opts)
end

function init()
	config.MakeCommand(PLUGIN_NAME, translate, config.NoComplete)
end
