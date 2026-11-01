# The Amazing Digital Circus

Welcome to the Amazing Digital Circus. Walk the tent, talk to the cast, and follow Caine into adventures he invents.

This is a beta. Expect bugs.

## Play

1. Install [Godot 4.7](https://godotengine.org/download).
2. Put `Godot_v4.7.2-stable_win64.exe` in the same folder as this project, or one folder above it.
3. Run `Play The Amazing Digital Circus.bat`.

You can also open `the-amazing-digital-circus/project.godot` in the Godot editor and press Play.

## Voices

The cast speaks through [Fish Audio](https://fish.audio). Copy `the-amazing-digital-circus/fish_keys.example.cfg` to `the-amazing-digital-circus/fish_keys.cfg` and fill in each character's API key and voice model. That file stays on your computer and is not part of this repository.

When Caine builds adventure characters, he searches Fish Audio for a voice. A popup asks you for an API key. The voice he picked is already filled in.

## Needs

Ollama running locally with `qwen2.5:1.5b` for Caine's adventures and chat. The address is `http://127.0.0.1:11434`.
