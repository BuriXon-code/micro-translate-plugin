# micro-translate-plugin

## About

![Banner](/banner.gif)

`micro-translate-plugin` is a small plugin for the Micro editor that translates selected text or the current line without leaving the editor.

It uses Google's public Translate endpoint through "curl", so it does not need a separate translator wrapper or any JSON library.

The plugin is simple, lightweight, and meant for fast translations while editing text.

## Installation

### Requirements:

- `curl` utility
- Micro with plugin support enabled (default)
- a shell that can run external commands

> [!NOTE]
> I recommend using the installed `curl` instead of the built-in `curl` from busybox/coreutils.

### Install the plugin with:

```sh
mkdir -p ~/.config/micro/plug
cd ~/.config/micro/plug
git clone https://github.com/BuriXon-code/micro-translate-plugin.git
```

Then make sure the plugin file is available as:

```
~/.config/micro/plug/micro-translate-plugin/translate.lua
```

If your Micro plugin directory is different, use that location instead.

## Usage

In Micro, open the command prompt with `CTRL + E` and run:

```
translate -t LANG [-s LANG] [-f timeout_seconds]
```

### Examples:

```
translate -t pl
translate -s en -t pl
translate -s auto -t de -f 10
```

### Behavior:

- if text is selected, the plugin translates the selection
- if nothing is selected, it translates the current line
- the result replaces the original text

### Arguments:

- `-t LANG` — target language, **required**
- `-s LANG` — source language, default is `auto`
- `-f SECONDS` — request timeout, default is `10`

> [!TIP]
> In most cases source lang `auto` is sufficient.
>
> The plugin uses the Google Translator endpoint, which recognizes the input language relatively correctly.

> [!WARNING] 
> Only language codes supported inside the plugin are accepted. If an invalid language code is used, the plugin returns an error instead of pretending the translation worked.
>
> You can find a full list of language codes **[here](/LANGUAGES.md)**..



### Typical workflow:

1. select some text
2. press `CTRL + E`
3. type the translation command
4. the plugin replaces the selected text with the translated output
5. if something fails, Micro shows an error message

## Support
### Contact me:
For any issues, suggestions, or questions, reach out via:

- *Email:* support@burixon.dev
- *Contact form:* [Click here](https://burixon.dev/contact/)
- *Bug reports:* [Click here](https://burixon.dev/bugreport/#micro-translate)

### Support me:
If you find this script useful, consider supporting my work by making a donation:

[**Donations**](https://burixon.dev/donate/)

Your contributions help in developing new projects and improving existing tools!
