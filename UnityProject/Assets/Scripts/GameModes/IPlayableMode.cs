using UnityEngine;

public interface IPlayableMode
{
    void OnMove(Vector2 direction);
    void OnCrossDown(); // X: Jump / Action 1 / Dodge
    void OnCrossUp();
    void OnSquareDown(); // []: Charge / Shoot / Punch / Swing
    void OnSquareUp(float chargeTime, float prqChance); // []: Release
    void OnTriangleDown(); // ^: Dunk / Kick / Heavy / Lob
    void OnTriangleUp();
    void OnCircleDown(); // O: Pass / Block / Parry
    void OnCircleUp();
    void StartMode();
    void EndMode();
}
