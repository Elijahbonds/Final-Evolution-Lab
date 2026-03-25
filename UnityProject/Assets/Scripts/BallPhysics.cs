using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
[RequireComponent(typeof(SphereCollider))]
public class BallPhysics : MonoBehaviour
{
    private Rigidbody _rb;
    private SphereCollider _collider;

    [Header("Ball Properties")]
    public float bounciness = 0.8f;
    public float friction = 0.2f;

    void Awake()
    {
        _rb = GetComponent<Rigidbody>();
        _collider = GetComponent<SphereCollider>();

        // Set Physics Material
        PhysicMaterial mat = new PhysicMaterial();
        mat.bounciness = bounciness;
        mat.dynamicFriction = friction;
        mat.staticFriction = friction;
        mat.bounceCombine = PhysicMaterialCombine.Maximum;
        _collider.material = mat;
    }

    public void SetHeld(bool held)
    {
        _rb.isKinematic = held;
        _collider.enabled = !held;
    }

    public void ShootTowards(Vector3 targetPosition, float power)
    {
        SetHeld(false);

        // Simple arc calculation
        Vector3 direction = targetPosition - transform.position;
        float distance = direction.magnitude;
        direction.y = distance * 0.5f; // Add vertical arc

        _rb.linearVelocity = direction.normalized * Mathf.Lerp(10f, 25f, power);
        _rb.angularVelocity = new Vector3(Mathf.Lerp(-10f, 10f, Random.value), 0, 0); // Backspin
    }
}
