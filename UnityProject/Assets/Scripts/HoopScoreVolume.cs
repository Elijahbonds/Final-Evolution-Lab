using UnityEngine;
using UnityEngine.Events;

[RequireComponent(typeof(BoxCollider))]
public class HoopScoreVolume : MonoBehaviour
{
    [Header("Hoop Settings")]
    public bool isHomeTeamBasket = false;
    public BasketballGameMode gameMode;
    
    [Header("Juice & Feedback")]
    public ParticleSystem netSwooshParticles;
    public AudioClip swooshSound;
    public UnityEvent OnScored;

    void Awake()
    {
        BoxCollider bc = GetComponent<BoxCollider>();
        bc.isTrigger = true;
    }

    void OnTriggerEnter(Collider other)
    {
        BallPhysics ball = other.GetComponent<BallPhysics>();
        if (ball != null)
        {
            // Only count if ball goes downward through hoop (y velocity < 0)
            if (other.attachedRigidbody.linearVelocity.y < -0.1f)
            {
                Debug.Log($"[HoopScoreVolume] Ball passed through {(isHomeTeamBasket ? "Home" : "Away")} basket!");
                
                int points = 2; // For 3-point logic, calculate distance from shooter
                
                gameMode?.ScoreBasket(isHomeTeamBasket, points);
                
                if (netSwooshParticles != null) netSwooshParticles.Play();
                if (swooshSound != null) AudioSource.PlayClipAtPoint(swooshSound, transform.position);
                
                OnScored?.Invoke();
            }
        }
    }
}
