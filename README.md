# Branching Insights App

An exploratory LLM interface that lets you wander through ideas by branching outward from each insight — rather than hunting for specific keywords you'd need to already know.

## How it works

1. **Start with a topic** — type anything and press Enter.
2. **Get an insight** — the LLM responds with a thought connected to your topic.
3. **Branch out** — three buttons appear, each offering a different direction the insight could lead. Pick one.
4. **Repeat forever** — every new insight spawns three more branches. There's no predetermined path; you're exploring the model's associative space by following what shows up.

The idea is that knowing which keywords to type requires knowing what's there to begin with. This flips that: you start from anywhere and let the branches guide you. The structure is a tree that grows as you walk it.

![ screenshot TBD ](path/to/screenshot.png)

## Building

Requires macOS with Xcode command line tools and libcurl headers.

```bash
make
```

This produces the `GeminiInsightApp` binary. The Makefile also includes an `app` target that wraps the binary in a `.app` bundle with an `Info.plist`.

```bash
make app
```

## Configuration

The OpenRouter API key is configured in `API_Client.c` and `main.m`. Replace the placeholder value with a real key before building:

```c
// API_Client.c
static const char *OPENROUTER_API_KEY = "sk-or-...";

// main.m
#define OPENROUTER_API_KEY "sk-or-..."
```

**Do not commit real keys.** The `.gitignore` and secret-scanning rules are set up to block them — keep the placeholder or use an environment variable.

## License

[Choose a license](https://choosealicense.com/) or add one later.
