using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(UIDocument))]
public class PS2OverlayInput : MonoBehaviour
{
    private UIDocument _doc;
    private float _chargeTime = 0f;
    private bool _isCharging = false;
    private float _prqSuccessChance = 0f; 
    private Vector2 _moveInput;

    void OnEnable()
    {
        _doc = GetComponent<UIDocument>();
        if (_doc == null || _doc.rootVisualElement == null) return;
        var root = _doc.rootVisualElement;

        var dpad = root.Q<VisualElement>("VirtualJoystick");
        dpad?.RegisterCallback<PointerMoveEvent>(evt => {
            Vector2 rawInput = evt.localPosition - (dpad.contentRect.size / 2f);
            _moveInput = rawInput.normalized * Mathf.Min(rawInput.magnitude / 50f, 1f);
        });
        dpad?.RegisterCallback<PointerUpEvent>(evt => _moveInput = Vector2.zero);

        root.Q<Button>("btn-cross")?.RegisterCallback<PointerDownEvent>(evt => GameModeManager.Instance.CurrentMode?.OnCrossDown());
        root.Q<Button>("btn-cross")?.RegisterCallback<PointerUpEvent>(evt => GameModeManager.Instance.CurrentMode?.OnCrossUp());
        
        root.Q<Button>("btn-square")?.RegisterCallback<PointerDownEvent>(evt => {
            _isCharging = true; _chargeTime = 0f;
            GameModeManager.Instance.CurrentMode?.OnSquareDown();
        });
        root.Q<Button>("btn-square")?.RegisterCallback<PointerUpEvent>(evt => {
            _isCharging = false;
            GameModeManager.Instance.CurrentMode?.OnSquareUp(Mathf.Clamp01(_chargeTime), _prqSuccessChance);
        });
        
        root.Q<Button>("btn-triangle")?.RegisterCallback<PointerDownEvent>(evt => GameModeManager.Instance.CurrentMode?.OnTriangleDown());
        root.Q<Button>("btn-triangle")?.RegisterCallback<PointerUpEvent>(evt => GameModeManager.Instance.CurrentMode?.OnTriangleUp());
        
        root.Q<Button>("btn-circle")?.RegisterCallback<PointerDownEvent>(evt => GameModeManager.Instance.CurrentMode?.OnCircleDown());
        root.Q<Button>("btn-circle")?.RegisterCallback<PointerUpEvent>(evt => GameModeManager.Instance.CurrentMode?.OnCircleUp());
    }

    void Update()
    {
        GameModeManager.Instance.CurrentMode?.OnMove(_moveInput);

        if (_isCharging)
        {
            _chargeTime += Time.deltaTime * 1.5f;
            // PRQ Ping Pong meter (0-100%)
            _prqSuccessChance = Mathf.PingPong(_chargeTime * 100f, 100f);
        }
    }
}
