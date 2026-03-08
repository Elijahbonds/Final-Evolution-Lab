using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerMovement : MonoBehaviour
{
    public float moveSpeed = 5f;
    public float rotationSpeed = 100f;
    public float dunkPower = 10f;
    public int dunkScoreDelta = 10;

    private Vector2 moveInput;
    private Rigidbody rb;
    private RorkNativeBridge rorkBridge;

    private void Awake()
    {
        rb = GetComponent<Rigidbody>();
        if (rb == null)
        {
            Debug.LogWarning("PlayerMovement: No Rigidbody found. Movement may not work as expected.");
        }

        rorkBridge = FindObjectOfType<RorkNativeBridge>();
    }

    // Called by PlayerInput action "Move".
    public void OnMove(InputAction.CallbackContext context)
    {
        moveInput = context.ReadValue<Vector2>();
    }

    // Called by PlayerInput action "Dunk".
    public void OnDunk(InputAction.CallbackContext context)
    {
        if (!context.performed)
        {
            return;
        }

        Debug.Log("[PlayerMovement] Dunk action performed.");

        if (rb != null)
        {
            rb.AddForce(Vector3.up * dunkPower, ForceMode.Impulse);
        }

        if (PlayerScoreManager.Instance == null)
        {
            Debug.LogError("[PlayerMovement] PlayerScoreManager.Instance is null.");
            return;
        }

        int currentScore = PlayerScoreManager.Instance.GetPlayerScore();
        int newScore = currentScore + dunkScoreDelta;
        PlayerScoreManager.Instance.UpdatePlayerScore(newScore);

        if (rorkBridge == null)
        {
            rorkBridge = FindObjectOfType<RorkNativeBridge>();
        }

        if (rorkBridge != null)
        {
            rorkBridge.PostRorkScoreToNative(newScore);
            Debug.Log($"[PlayerMovement] Posted score {newScore} to native.");
        }
        else
        {
            Debug.LogError("[PlayerMovement] RorkNativeBridge not found. Cannot post score to native.");
        }
    }

    private void FixedUpdate()
    {
        if (rb == null)
        {
            return;
        }

        Vector3 movement = new Vector3(moveInput.x, 0f, moveInput.y) * moveSpeed * Time.fixedDeltaTime;
        rb.MovePosition(rb.position + transform.TransformDirection(movement));

        if (moveInput != Vector2.zero)
        {
            Quaternion targetRotation = Quaternion.LookRotation(new Vector3(moveInput.x, 0f, moveInput.y));
            rb.rotation = Quaternion.RotateTowards(rb.rotation, targetRotation, rotationSpeed * Time.fixedDeltaTime);
        }
    }
}
