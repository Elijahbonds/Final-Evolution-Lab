# Unity 6 Migration Rules

> **Status: reference/prototype only.** Unreal Engine 5.7 is now the production shipping target. Do not use this document to change the shipping app shell unless leadership reopens the Unity migration.

---

The rules below are retained for historical context and for any prototype work that references the Unity project. They do not override `SHIPPING_ARCHITECTURE.md`.

## Original migration scope (archived)

- Unity 6 was previously considered as a migration target for the iOS app shell.
- That direction has been superseded by the Unreal Engine 5.7 re-baseline.
- Unity code in `UnityProject/` and `Unity/` remains as prototype/reference material.

## If leadership reopens Unity migration

Only proceed if there is an explicit, written leadership decision reversing the Unreal re-baseline. In that case:

1. Update `SHIPPING_ARCHITECTURE.md` first.
2. Update `infra/SHIPPING.md` to reflect the new canonical path.
3. Notify all agents and update `.cursorrules`.

---

*Status: frozen. Production target is Unreal Engine 5.7.*
