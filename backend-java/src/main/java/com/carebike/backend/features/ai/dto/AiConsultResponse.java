package com.carebike.backend.features.ai.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AiConsultResponse {
    private String reply;
    private Integer vehicleId;
    private String vehicleLabel;
    private String intent;
    private String urgency;
    private List<AiHealthCard> healthCards = new ArrayList<>();
    private List<AiSuggestedAction> actions = new ArrayList<>();

    public AiConsultResponse(String reply) {
        this.reply = reply;
    }
}
