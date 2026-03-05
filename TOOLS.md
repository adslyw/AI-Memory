# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

### AI Skills

- **web-search**: Use `inference.sh` CLI for web search and content extraction.
  - **Tavily Search**: `infsh app run tavily/search-assistant --input '{"query": "latest AI developments 2024"}'`
  - **Tavily Extract**: `infsh app run tavily/extract --input '{"urls": ["https://example.com/article1"]}'`
  - **Exa Search**: `infsh app run exa/search --input '{"query": "machine learning frameworks comparison"}'`
  - **Exa Answer**: `infsh app run exa/answer --input '{"question": "What is the population of Tokyo?"}'`
  - **Exa Extract**: `infsh app run exa/extract --input '{"url": "https://example.com/research-paper"}'`

