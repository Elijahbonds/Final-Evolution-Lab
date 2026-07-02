# Integration branch

- **Canonical handoff branch:** `setup-healthkit`
- **Do not** wholesale-merge legacy branches whose history reintroduces Unity bridge experiments, deleted Unreal integration, or sideload/OTA distribution artifacts.
- **Cherry-pick** individual files/commits only after diff review against App Store–aligned Unreal iOS shipping.

When automating (CI, Windsurf, Superapp release jobs), **clone/checkout `setup-healthkit`** unless you have an explicit merge policy document elsewhere.
