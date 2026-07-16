package com.carebike.backend.features.websocket.service;

import com.carebike.backend.features.websocket.dto.UpdateEvent;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Service
public class WebSocketEventService {

    private SimpMessagingTemplate messagingTemplate;

    @Autowired(required = false)
    @Lazy
    public void setMessagingTemplate(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    public void sendGlobalUpdate(String eventType) {
        SimpMessagingTemplate template = messagingTemplate;
        if (template == null) return;

        sendAfterCommit(() ->
            template.convertAndSend("/topic/global/updates", new UpdateEvent(eventType, ""))
        );
    }

    public void sendBranchUpdate(Integer branchId, String eventType) {
        SimpMessagingTemplate template = messagingTemplate;
        if (template == null || branchId == null) return;

        sendAfterCommit(() ->
            template.convertAndSend(
                "/topic/branches/" + branchId + "/updates",
                new UpdateEvent(eventType, "")
            )
        );
    }

    public void sendBranchTopic(Integer branchId, String topic, Object payload) {
        SimpMessagingTemplate template = messagingTemplate;
        if (template == null || branchId == null || topic == null || topic.isBlank()) return;

        sendAfterCommit(() -> template.convertAndSend(
            "/topic/branches/" + branchId + "/" + topic,
            payload
        ));
    }

    private void sendAfterCommit(Runnable sendAction) {
        if (TransactionSynchronizationManager.isActualTransactionActive()
                && TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(
                new TransactionSynchronization() {
                    @Override
                    public void afterCommit() {
                        sendAction.run();
                    }
                }
            );
            return;
        }

        sendAction.run();
    }
}
