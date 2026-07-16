package com.carebike.backend.features.websocket.dto;

public record UpdateEvent(
    String type,
    String message
) {}
