using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class NativeBridgeTestButton : MonoBehaviour
{
    public RorkNativeBridge rorkNativeBridge;
    public Button button;
    public TextMeshProUGUI buttonText;

    [SerializeField]
    private int scoreToSend = 50;

    private void Start()
    {
        if (button == null)
        {
            button = GetComponent<Button>();
        }

        if (buttonText == null)
        {
            buttonText = GetComponentInChildren<TextMeshProUGUI>();
        }

        if (button != null)
        {
            button.onClick.AddListener(OnButtonClick);
        }

        UpdateButtonText();
    }

    private void OnDestroy()
    {
        if (button != null)
        {
            button.onClick.RemoveListener(OnButtonClick);
        }
    }

    private void OnButtonClick()
    {
        if (rorkNativeBridge == null)
        {
            Debug.LogError("[NativeBridgeTestButton] Missing RorkNativeBridge reference.");
            return;
        }

        scoreToSend += 10;
        if (scoreToSend > 99)
        {
            scoreToSend = 30;
        }

        rorkNativeBridge.PostRorkScoreToNative(scoreToSend);
        UpdateButtonText();
    }

    private void UpdateButtonText()
    {
        if (buttonText != null)
        {
            buttonText.text = $"Send PRQ: {scoreToSend}";
        }
    }
}
