# Moved

Scene descriptors now live in **`FinalEvolutionLab/Resources/NexusScenes/`**,
where the app's synchronized root group bundles them automatically so
`NexusSceneLoader` can find them at runtime. Nothing here was ever bundled.

The `basketball_h2h.nexus.json` that used to sit in this folder was **deleted,
not moved**: it was hand-written against a schema the Swift model does not
use, and had never decoded —

```
typeMismatch(Array<Any> … "Expected to decode Array<Any> but found a dictionary")
```

All 20 descriptors are now **generated from the Swift types**:

```bash
bash tools/nexus_scenes.sh --write   # regenerate
bash tools/nexus_scenes.sh           # verify all 20 load
```

Do not hand-edit descriptors. Change the model or the generator, then
regenerate — that is what keeps the JSON and the types from drifting apart
again.
