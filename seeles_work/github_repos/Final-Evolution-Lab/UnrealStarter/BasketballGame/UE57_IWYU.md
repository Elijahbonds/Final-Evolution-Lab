# UE 5.5+ / 5.7 include order (IWYU)

Unreal’s build treats the **matching `.h` file as the first include** in each `.cpp`. If `FinalEvolutionLab.h` comes first, you get:

`Expected FELBasketballGameMode.h to be first header included.`

**Pattern:**

```cpp
#include "FELBasketballCharacter.h"
#include "FinalEvolutionLab.h"
// … other includes …
```

**Characters:** include **`Components/CapsuleComponent.h`** before calling **`GetCapsuleComponent()`** in `.cpp`, or the type is only forward-declared and **`SetupAttachment`** fails to compile.
