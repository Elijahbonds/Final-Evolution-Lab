using UnityEngine;

/// <summary>
/// Storm x Matrix style 1v1/3v3 basketball mechanics.
/// Adapted to fit the IPlayableMode unified interface.
/// </summary>
public class BasketballMode : MonoBehaviour, IPlayableMode
{
    private CharacterController _player;
    private Vector3 _velocity;
    private bool _isGrounded;

    [Header("Movement")]
    public float speed = 6.0f;
    public float jumpHeight = 2.5f;
    public float gravity = -19.81f;
    public float turnSmoothTime = 0.1f;
    private float _turnSmoothVelocity;

    [Header("Gameplay")]
    public Transform ballHoldPosition;
    public GameObject basketballPrefab;
    private GameObject _heldBall;
    public bool isHoldingBall = false;
    public Transform currentHoop;

    private Vector2 _currentMoveDir;

    void Awake()
    {
        _player = GetComponent<CharacterController>();
        if (isHoldingBall && basketballPrefab != null)
        {
            GrabBall(Instantiate(basketballPrefab, ballHoldPosition.position, Quaternion.identity));
        }
    }

    public void StartMode() { Debug.Log("[Basketball] Tip Off!"); }
    public void EndMode() { Debug.Log("[Basketball] Buzzer Beater!"); }

    public void OnMove(Vector2 direction)
    {
        _currentMoveDir = direction;
    }

    void Update()
    {
        _isGrounded = _player.isGrounded;
        if (_isGrounded && _velocity.y < 0)
        {
            _velocity.y = -2f;
        }

        Vector3 direction = new Vector3(_currentMoveDir.x, 0f, _currentMoveDir.y).normalized;

        if (direction.magnitude >= 0.1f)
        {
            float targetAngle = Mathf.Atan2(direction.x, direction.z) * Mathf.Rad2Deg;
            float angle = Mathf.SmoothDampAngle(transform.eulerAngles.y, targetAngle, ref _turnSmoothVelocity, turnSmoothTime);
            transform.rotation = Quaternion.Euler(0f, angle, 0f);

            Vector3 moveDir = Quaternion.Euler(0f, targetAngle, 0f) * Vector3.forward;
            _player.Move(moveDir.normalized * speed * Time.deltaTime);
        }

        _velocity.y += gravity * Time.deltaTime;
        _player.Move(_velocity * Time.deltaTime);
    }

    public void OnCrossDown() 
    {
        if (_isGrounded)
        {
            Debug.Log("[Basketball] Jump!");
            _velocity.y = Mathf.Sqrt(jumpHeight * -2f * gravity);
        }
    }
    public void OnCrossUp() {}

    public void OnSquareDown() 
    {
        Debug.Log("[Basketball] Charging Shot...");
    }

    public void OnSquareUp(float chargeTime, float prqChance) 
    {
        if (!isHoldingBall || _heldBall == null) return;
        Debug.Log($"[Basketball] Releasing Shot! PRQ: {prqChance}%");

        _heldBall.transform.parent = null;
        BallPhysics bp = _heldBall.GetComponent<BallPhysics>();
        if (bp != null && currentHoop != null)
        {
            float accuracyModifier = (prqChance > 85f) ? 1.2f : 0.8f;
            bp.ShootTowards(currentHoop.position, Mathf.Clamp01(chargeTime) * accuracyModifier);
        }

        _heldBall = null;
        isHoldingBall = false;
    }

    public void OnTriangleDown() 
    {
        if (!isHoldingBall) return;
        Debug.Log("[Basketball] Executing Dunk!");
        if (_isGrounded) _velocity.y = Mathf.Sqrt(jumpHeight * -2f * gravity);
        OnSquareUp(1f, 100f); // Auto score after dunk for now
    }
    public void OnTriangleUp() {}

    public void OnCircleDown() { Debug.Log("[Basketball] Pass"); }
    public void OnCircleUp() {}

    public void GrabBall(GameObject ball)
    {
        _heldBall = ball;
        isHoldingBall = true;
        
        BallPhysics bp = _heldBall.GetComponent<BallPhysics>();
        if (bp != null) bp.SetHeld(true);

        _heldBall.transform.parent = ballHoldPosition;
        _heldBall.transform.localPosition = Vector3.zero;
    }
}
