using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using TMPro;
using UnityEngine.UI;

public class SettingsMenu : MonoBehaviour
{

    public GameObject PointCloudCreator;

    public Slider PointSizeSlider;
    public TextMeshProUGUI PointSizeText;
    private float defaultPointSize;

    void start()
    {
        // Get default point size and set slider and default
        QuestPointCloudBillboards billboards = PointCloudCreator.GetComponentInChildren<QuestPointCloudBillboards>();
        defaultPointSize = billboards.pointSizeMeters;
        PointSizeSlider.value = defaultPointSize;
    }

    /// <summary>
    /// Update the menu to display the point slider value,
    /// and update the actual size of the displayed points in the PointCloudCreator
    /// </summary>
    public void pointSlider()
    {
        PointSizeText.text = PointSizeSlider.value.ToString();
        QuestPointCloudBillboards billboards = PointCloudCreator.GetComponentInChildren<QuestPointCloudBillboards>();

        billboards.pointSizeMeters = PointSizeSlider.value;


    }

    /// <summary>
    /// Reset all settings in the settings menu to defaults saved on start
    /// </summary>
    public void ResetSetting()
    {
        PointSizeSlider.value = defaultPointSize;
    }
}
