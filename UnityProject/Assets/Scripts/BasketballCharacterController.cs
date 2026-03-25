using UnityEngine;

[RequireComponent(typeof(CharacterController))]
public class BasketballCharacterController : MonoBehaviour
{
    private CharacterController _controller;
    private Vector3 _velocity;
    private bool _isGrounded;

    [Header("Movement")]
    public float speed = 6.0f;
    public float jumpHeight = 2.5f;
    public float gravity = -19.81f;
    public float turnSmoothTime = 0.1f;
    private float _turnSmoothVelocity;

    [Header("Gameplay (PRQ & Actions)")]
    public Transform ballHoldPosition;
    public GameObject basketballPrefab;
    private GameObject _heldBall;
    public bool isHoldingBall = false;

    // References to UI joystick (Assumes a simple public static or singleton input manager)
    public Vector2 inputDirection;

    void Awake()
    {
        _controller = GetComponent<CharacterController>();
        if (isHoldingBall && basketballPrefab != null)
        {
            GrabBall(Instantiate(basketballPrefab, ballHoldPosition.position, Quaternion.identity));
        }
    }

    void Update()
    {
        _isGrounded = _controller.isGrounded;
        if (_isGrounded && _velocity.y < 0)
        {
            _velocity.y = -2f;
        }

        // Movement
        Vector3 direction = new Vector3(inputDirection.x, 0f, inputDirection.y).normalized;

        if (direction.magnitude >= 0.1f)
        {
            float targetAngle = Mathf.Atan2(direction.x, direction.z) * Mathf.Rad2Deg;
            float angle = Mathf.SmoothDampAngle(transform.eulerAngles.y, targetAngle, ref _turnSmoothVelocity, turnSmoothTime);
            transform.rotation = Quaternion.Euler(0f, angle, 0f);

            Vector3 moveDir = Quaternion.Euler(0f, targetAngle, 0f) * Vector3.forward;
            _controller.Move(moveDir.normalized * speed * Time.deltaTime);
        }

        // Gravity
        _velocity.y += gravity * Time.deltaTime;
        _controller.Move(_velocity * Time.deltaTime);
    }

    public void Jump()
    {
        if (_isGrounded)
        {
            _velocity.y = Mathf.Sqrt(jumpHeight * -2f * gravity);
        }
    }

    public void Shoot(float chargePower, Transform targetHoop)
    {
        if (!isHoldingBall || _heldBall == null) return;

        // Detach ball and apply physics
        _heldBall.transform.parent = null;
        BallPhysics bp = _heldBall.GetComponent<BallPhysics>();
        if (bp != null)
        {
            bp.ShootTowards(targetHoop.position, chargePower);
        }

        _heldBall = null;
        isHoldingBall = false;
        
        Debug.Log("[BasketballCharacter] Shot fired!");
    }

    public void Dunk(Transform targetHoop)
    {
        if (!isHoldingBall) return;
        Debug.Log("[BasketballCharacter] Executing NBA Live 06 style Dunk!");
        // TODO: Play dunk animation, teleport/lerp to rim, score
        Jump(); 
        // For now, auto-score after delay
        Shoot(1f, targetHoop);
    }

    public void GrabBall(GameObject ball)
    {
        _heldBall = ball;
        isHoldingBall = true;
        
        // Disable ball physics while holding
        BallPhysics bp = _heldBall.GetComponent<BallPhysics>();
        if (bp != null) bp.SetHeld(true);

        _heldBall.transform.parent = ballHoldPosition;
        _heldBall.transform.localPosition = Vector3.zero;
    }
}
