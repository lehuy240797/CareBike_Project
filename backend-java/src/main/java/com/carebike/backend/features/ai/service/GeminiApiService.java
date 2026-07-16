package com.carebike.backend.features.ai.service;

import com.carebike.backend.features.ai.dto.AiConsultRequest;
import com.carebike.backend.features.ai.dto.AiConsultResponse;
import com.carebike.backend.features.ai.dto.AiHealthCard;
import com.carebike.backend.features.ai.dto.AiSuggestedAction;
import com.carebike.backend.features.ai.dto.GeminiRequest;
import com.carebike.backend.features.ai.dto.GeminiResponse;
import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.maintenance.entity.MaintenanceHistory;
import com.carebike.backend.features.maintenance.repository.MaintenanceHistoryRepository;
import com.carebike.backend.features.vehicle.entity.Vehicle;
import com.carebike.backend.features.vehicle.repository.VehicleRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.text.Normalizer;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

@Service
public class GeminiApiService {

    private static final Logger logger = LoggerFactory.getLogger(GeminiApiService.class);
    private static final int OIL_INTERVAL_KM = 2_000;
    private static final int OIL_INTERVAL_DAYS = 90;
    private static final int BRAKE_CHECK_INTERVAL_DAYS = 180;
    private static final int TIRE_CHECK_INTERVAL_DAYS = 180;

    @Value("${gemini.api.url}")
    private String geminiApiUrl;

    @Value("${gemini.api.key}")
    private String geminiApiKey;

    private final RestTemplate restTemplate;
    private final AppointmentRepository appointmentRepository;
    private final MaintenanceHistoryRepository maintenanceHistoryRepository;
    private final VehicleRepository vehicleRepository;

    public GeminiApiService(
            RestTemplate restTemplate,
            AppointmentRepository appointmentRepository,
            MaintenanceHistoryRepository maintenanceHistoryRepository,
            VehicleRepository vehicleRepository
    ) {
        this.restTemplate = restTemplate;
        this.appointmentRepository = appointmentRepository;
        this.maintenanceHistoryRepository = maintenanceHistoryRepository;
        this.vehicleRepository = vehicleRepository;
    }

    public AiConsultResponse getAiConsultation(AiConsultRequest request) {
        if (request == null || request.getCustomerId() == null) {
            return loginRequiredResponse();
        }

        Integer customerId = request.getCustomerId();
        String message = clean(request.getMessage());
        List<Vehicle> vehicles = vehicleRepository.findByOwnerId(customerId);
        Optional<Vehicle> selectedVehicle = resolveVehicle(vehicles, request.getVehicleId());

        if (vehicles.isEmpty()) {
            return noVehicleResponse();
        }

        if (selectedVehicle.isEmpty()) {
            return selectVehicleResponse(vehicles);
        }

        Vehicle vehicle = selectedVehicle.get();
        List<Appointment> appointments = appointmentRepository.findByCustomer_IdOrderByIdDesc(customerId);
        List<Appointment> vehicleAppointments = filterVehicleAppointments(appointments, vehicle);
        List<MaintenanceHistory> histories = maintenanceHistoryRepository.findByCustomer_IdOrderByServiceDateDescIdDesc(customerId);
        ChatIntent intent = detectIntent(message);
        boolean allowGenericHistory = vehicles.size() == 1;
        List<AiHealthCard> healthCards = buildHealthCards(vehicle, vehicleAppointments, histories, allowGenericHistory);
        List<AiSuggestedAction> actions = buildActions(intent, vehicle);
        String fallbackReply = buildRuleReply(intent, vehicle);
        String prompt = buildPrompt(
                message,
                vehicle,
                intent,
                healthCards,
                vehicleAppointments,
                allowGenericHistory ? histories : List.of(),
                fallbackReply
        );

        String reply;
        try {
            reply = stripActionTags(callGeminiApi(prompt));
        } catch (RuntimeException ex) {
            logger.warn("Using rule-based AI fallback: {}", ex.getMessage());
            reply = fallbackReply;
        }

        return new AiConsultResponse(
                reply,
                vehicle.getId(),
                vehicleLabel(vehicle),
                intent.name(),
                urgencyFor(intent),
                healthCards,
                actions
        );
    }

    private Optional<Vehicle> resolveVehicle(List<Vehicle> vehicles, Integer requestedVehicleId) {
        if (requestedVehicleId != null) {
            return vehicles.stream()
                    .filter(vehicle -> requestedVehicleId.equals(vehicle.getId()))
                    .findFirst();
        }
        return vehicles.size() == 1 ? Optional.of(vehicles.get(0)) : Optional.empty();
    }

    private List<Appointment> filterVehicleAppointments(List<Appointment> appointments, Vehicle vehicle) {
        Integer vehicleId = vehicle.getId();
        if (vehicleId == null) {
            return List.of();
        }
        return appointments.stream()
                .filter(appointment -> vehicleId.equals(appointment.getVehicleId()))
                .toList();
    }

    private AiConsultResponse loginRequiredResponse() {
        return new AiConsultResponse(
                "Please log in again so I can read your vehicle profile and maintenance history.",
                null,
                null,
                ChatIntent.VEHICLE_SELECTION.name(),
                "LOW",
                List.of(),
                List.of()
        );
    }

    private AiConsultResponse noVehicleResponse() {
        return new AiConsultResponse(
                "I need a saved vehicle before I can give personal maintenance advice. Please add your motorbike in My Vehicles first.",
                null,
                null,
                ChatIntent.VEHICLE_SELECTION.name(),
                "LOW",
                List.of(),
                List.of(new AiSuggestedAction("ADD_VEHICLE", "Add vehicle", null))
        );
    }

    private AiConsultResponse selectVehicleResponse(List<Vehicle> vehicles) {
        List<AiSuggestedAction> actions = vehicles.stream()
                .map(vehicle -> new AiSuggestedAction("SELECT_VEHICLE", vehicleLabel(vehicle), String.valueOf(vehicle.getId())))
                .toList();
        return new AiConsultResponse(
                "Which vehicle should I use for this advice? Choose one so I can check the right maintenance history and odometer.",
                null,
                null,
                ChatIntent.VEHICLE_SELECTION.name(),
                "LOW",
                List.of(),
                actions
        );
    }

    private ChatIntent detectIntent(String message) {
        String lower = normalize(message);
        if (containsAny(lower, "rescue", "sos", "emergency", "khong no", "mat phanh")) {
            return ChatIntent.RESCUE;
        }
        if (containsAny(lower, "book", "booking", "appointment", "checkup", "dat lich")) {
            return ChatIntent.BOOKING;
        }
        if (containsAny(lower, "brake", "phanh", "thang")) {
            return ChatIntent.BRAKE;
        }
        if (containsAny(lower, "tire", "tyre", "lop", "vo xe")) {
            return ChatIntent.TIRE;
        }
        if (containsAny(lower, "oil", "nhot", "dau may", "dau nhot")) {
            return ChatIntent.OIL;
        }
        if (containsAny(lower, "history", "lich su")) {
            return ChatIntent.HISTORY;
        }
        return ChatIntent.GENERAL;
    }

    private List<AiHealthCard> buildHealthCards(
            Vehicle vehicle,
            List<Appointment> vehicleAppointments,
            List<MaintenanceHistory> histories,
            boolean allowGenericHistory
    ) {
        List<AiHealthCard> cards = new ArrayList<>();
        cards.add(oilCard(vehicle, vehicleAppointments, histories, allowGenericHistory));
        cards.add(serviceAgeCard(
                "Brake",
                vehicleAppointments,
                histories,
                allowGenericHistory,
                BRAKE_CHECK_INTERVAL_DAYS,
                "brake",
                "phanh",
                "thang"
        ));
        cards.add(serviceAgeCard(
                "Tire",
                vehicleAppointments,
                histories,
                allowGenericHistory,
                TIRE_CHECK_INTERVAL_DAYS,
                "tire",
                "tyre",
                "lop",
                "vo xe"
        ));
        return cards;
    }

    private AiHealthCard oilCard(
            Vehicle vehicle,
            List<Appointment> vehicleAppointments,
            List<MaintenanceHistory> histories,
            boolean allowGenericHistory
    ) {
        Optional<Appointment> lastOilAppointment = findLatestAppointmentService(
                vehicleAppointments,
                "oil",
                "nhot",
                "dau may",
                "dau nhot"
        );
        if (lastOilAppointment.isPresent()) {
            Appointment appointment = lastOilAppointment.get();
            Integer currentKm = vehicle.getCurrentKm();
            Integer lastKm = appointment.getCurrentKm();
            long days = daysSince(appointment);
            boolean dueByKm = currentKm != null && lastKm != null && currentKm - lastKm >= OIL_INTERVAL_KM;
            boolean dueByTime = days >= OIL_INTERVAL_DAYS;
            String detail = "Last oil service: " + formatDate(appointment) + detailKm(currentKm, lastKm);
            return new AiHealthCard("Oil", dueByKm || dueByTime ? "Due soon" : "OK", detail, dueByKm || dueByTime ? "warning" : "success");
        }

        if (!allowGenericHistory) {
            return new AiHealthCard("Oil", "Unknown", "No oil-change record found for this vehicle", "warning");
        }

        Optional<MaintenanceHistory> lastOil = findLatestService(histories, "oil", "nhot", "dau may", "dau nhot");
        if (lastOil.isEmpty()) {
            return new AiHealthCard("Oil", "Unknown", "No oil-change record found", "warning");
        }

        MaintenanceHistory record = lastOil.get();
        Integer currentKm = vehicle.getCurrentKm();
        Integer lastKm = record.getCurrentKm();
        long days = daysSince(record);
        boolean dueByKm = currentKm != null && lastKm != null && currentKm - lastKm >= OIL_INTERVAL_KM;
        boolean dueByTime = days >= OIL_INTERVAL_DAYS;

        if (dueByKm || dueByTime) {
            return new AiHealthCard("Oil", "Due soon", "Last oil service: " + formatDate(record) + detailKm(currentKm, lastKm), "warning");
        }
        return new AiHealthCard("Oil", "OK", "Last oil service: " + formatDate(record) + detailKm(currentKm, lastKm), "success");
    }

    private AiHealthCard serviceAgeCard(
            String label,
            List<Appointment> vehicleAppointments,
            List<MaintenanceHistory> histories,
            boolean allowGenericHistory,
            int intervalDays,
            String... keywords
    ) {
        Optional<Appointment> vehicleRecord = findLatestAppointmentService(vehicleAppointments, keywords);
        if (vehicleRecord.isPresent()) {
            Appointment appointment = vehicleRecord.get();
            long days = daysSince(appointment);
            if (days >= intervalDays) {
                return new AiHealthCard(label, "Check soon", "Last record: " + formatDate(appointment), "warning");
            }
            return new AiHealthCard(label, "OK", "Last record: " + formatDate(appointment), "success");
        }

        if (!allowGenericHistory) {
            return new AiHealthCard(label, "Unknown", "No matching record found for this vehicle", "warning");
        }

        Optional<MaintenanceHistory> latest = findLatestService(histories, keywords);
        if (latest.isEmpty()) {
            return new AiHealthCard(label, "Unknown", "No matching service record found", "warning");
        }

        MaintenanceHistory record = latest.get();
        long days = daysSince(record);
        if (days >= intervalDays) {
            return new AiHealthCard(label, "Check soon", "Last record: " + formatDate(record), "warning");
        }
        return new AiHealthCard(label, "OK", "Last record: " + formatDate(record), "success");
    }

    private Optional<MaintenanceHistory> findLatestService(List<MaintenanceHistory> histories, String... keywords) {
        return histories.stream()
                .filter(history -> history.getServiceDate() != null)
                .filter(history -> containsAny(normalize(history.getServiceDetails()), keywords))
                .max(Comparator
                        .comparing(MaintenanceHistory::getServiceDate)
                        .thenComparing(MaintenanceHistory::getId));
    }

    private Optional<Appointment> findLatestAppointmentService(List<Appointment> appointments, String... keywords) {
        return appointments.stream()
                .filter(appointment -> "COMPLETED".equalsIgnoreCase(appointment.getStatus()))
                .filter(appointment -> appointment.getAppointmentDate() != null)
                .filter(appointment -> containsAny(appointmentSearchText(appointment), keywords))
                .max(Comparator.comparing(Appointment::getAppointmentDate));
    }

    private String appointmentSearchText(Appointment appointment) {
        return normalize(clean(appointment.getNote()) + " " + clean(appointment.getInvoiceDetails()));
    }

    private List<AiSuggestedAction> buildActions(ChatIntent intent, Vehicle vehicle) {
        List<AiSuggestedAction> actions = new ArrayList<>();
        switch (intent) {
            case RESCUE -> actions.add(new AiSuggestedAction("RESCUE", "Call rescue", null));
            case BOOKING -> actions.add(new AiSuggestedAction("BOOKING", "Book a checkup", String.valueOf(vehicle.getId())));
            case TIRE -> {
                actions.add(new AiSuggestedAction("AI_TIRE_SCAN", "Scan tire", String.valueOf(vehicle.getId())));
                actions.add(new AiSuggestedAction("BOOKING", "Book tire check", String.valueOf(vehicle.getId())));
            }
            case BRAKE -> actions.add(new AiSuggestedAction("BOOKING", "Book brake check", String.valueOf(vehicle.getId())));
            case OIL -> actions.add(new AiSuggestedAction("BOOKING", "Book oil service", String.valueOf(vehicle.getId())));
            case HISTORY -> actions.add(new AiSuggestedAction("VIEW_HISTORY", "View history", String.valueOf(vehicle.getId())));
            default -> {
                actions.add(new AiSuggestedAction("AI_TIRE_SCAN", "Scan tire", String.valueOf(vehicle.getId())));
                actions.add(new AiSuggestedAction("BOOKING", "Book checkup", String.valueOf(vehicle.getId())));
            }
        }
        return actions;
    }

    private String buildRuleReply(ChatIntent intent, Vehicle vehicle) {
        String label = vehicleLabel(vehicle);
        return switch (intent) {
            case OIL -> "For " + label + ", check the Oil card above. If it says Due soon, book an oil service; otherwise keep monitoring by mileage and date.";
            case BRAKE -> "For " + label + ", soft braking should be checked soon. Avoid high speed or heavy loads, and book a brake inspection if lever travel feels longer than usual.";
            case TIRE -> "For " + label + ", tire safety depends on tread depth, cracks, pressure, and age. Use AI Tire Scan for a photo check, then book a technician check if wear is visible.";
            case RESCUE -> "If the bike cannot start, loses braking, leaks heavily, or feels unsafe, stop riding and request CareBike rescue now.";
            case BOOKING -> "I can help prepare a checkup for " + label + ". The health cards above show what the branch should inspect first.";
            case HISTORY -> "Here is the current maintenance snapshot for " + label + ". Use it to decide whether to book service or keep monitoring.";
            default -> "For " + label + ", I checked your maintenance snapshot. Focus on any card marked Due soon or Check soon, and book a checkup if you notice noise, vibration, weak braking, or tire wear.";
        };
    }

    private String buildPrompt(
            String userMessage,
            Vehicle vehicle,
            ChatIntent intent,
            List<AiHealthCard> healthCards,
            List<Appointment> appointments,
            List<MaintenanceHistory> histories,
            String fallbackReply
    ) {
        return """
                You are CareBike AI, a concise motorcycle maintenance copilot.
                Reply in the same language as the user's message.
                Start with the decision or next step. Do not ask which vehicle to inspect; the selected vehicle is already provided.
                Keep the answer under 90 words. Do not invent prices, appointments, or safety guarantees.
                Recommend booking only when the issue, health cards, or user intent make it useful.

                Selected vehicle:
                %s

                User message:
                %s

                Detected intent: %s

                Health cards:
                %s

                Recent appointments:
                %s

                Recent maintenance history:
                %s

                If the model is unsure, use this safe fallback:
                %s
                """.formatted(
                vehicleLine(vehicle),
                userMessage,
                intent.name(),
                formatHealthCards(healthCards),
                formatAppointments(appointments),
                formatHistories(histories),
                fallbackReply
        );
    }

    private String callGeminiApi(String prompt) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("x-goog-api-key", geminiApiKey);

            GeminiRequest requestBody = GeminiRequest.fromPrompt(prompt);
            HttpEntity<GeminiRequest> httpEntity = new HttpEntity<>(requestBody, headers);
            ResponseEntity<GeminiResponse> responseEntity = restTemplate.postForEntity(
                    geminiApiUrl,
                    httpEntity,
                    GeminiResponse.class
            );

            GeminiResponse geminiResponse = responseEntity.getBody();
            if (geminiResponse == null) {
                throw new RuntimeException("Gemini returned an empty response.");
            }

            String aiReply = geminiResponse.extractTextResponse();
            if (aiReply.isBlank()) {
                throw new RuntimeException("Gemini returned no text.");
            }

            return aiReply.trim();
        } catch (RuntimeException ex) {
            throw ex;
        } catch (Exception ex) {
            logger.error("Gemini call failed: {}", ex.getMessage(), ex);
            throw new RuntimeException("AI service is temporarily unavailable.");
        }
    }

    private String formatAppointments(List<Appointment> appointments) {
        return appointments.stream()
                .filter(appointment -> "COMPLETED".equalsIgnoreCase(appointment.getStatus()))
                .limit(3)
                .map(appointment -> "- " + appointment.getAppointmentDate()
                        + ", vehicle=" + clean(appointment.getVehicleBrand()) + " " + clean(appointment.getVehicleName())
                        + ", note=" + clean(appointment.getNote()))
                .toList()
                .toString();
    }

    private String formatHistories(List<MaintenanceHistory> histories) {
        return histories.stream()
                .limit(5)
                .map(history -> "- " + history.getServiceDate()
                        + ", km=" + history.getCurrentKm()
                        + ", service=" + clean(history.getServiceDetails()))
                .toList()
                .toString();
    }

    private String formatHealthCards(List<AiHealthCard> cards) {
        return cards.stream()
                .map(card -> card.label() + ": " + card.status() + " (" + card.detail() + ")")
                .toList()
                .toString();
    }

    private String urgencyFor(ChatIntent intent) {
        return switch (intent) {
            case RESCUE -> "HIGH";
            case BRAKE, TIRE -> "MEDIUM";
            default -> "LOW";
        };
    }

    private String stripActionTags(String reply) {
        return reply
                .replace("[ACTION:RESCUE]", "")
                .replace("[ACTION:BOOKING]", "")
                .trim();
    }

    private String vehicleLabel(Vehicle vehicle) {
        String label = clean(vehicle.getBrand()) + " " + clean(vehicle.getVehicleName());
        if (!clean(vehicle.getLicensePlate()).isBlank()) {
            label += " - " + clean(vehicle.getLicensePlate());
        }
        return label.trim();
    }

    private String vehicleLine(Vehicle vehicle) {
        return vehicleLabel(vehicle)
                + ", type=" + clean(vehicle.getVehicleType())
                + ", engine=" + vehicle.getEngineCapacity()
                + "cc, odometer=" + vehicle.getCurrentKm() + "km";
    }

    private String formatDate(MaintenanceHistory history) {
        return history.getServiceDate() == null ? "unknown date" : history.getServiceDate().toString();
    }

    private String formatDate(Appointment appointment) {
        return appointment.getAppointmentDate() == null ? "unknown date" : appointment.getAppointmentDate().toLocalDate().toString();
    }

    private String detailKm(Integer currentKm, Integer lastKm) {
        if (currentKm == null || lastKm == null) {
            return "";
        }
        return ", " + Math.max(0, currentKm - lastKm) + " km since then";
    }

    private long daysSince(MaintenanceHistory history) {
        if (history.getServiceDate() == null) {
            return 0;
        }
        return ChronoUnit.DAYS.between(history.getServiceDate(), LocalDate.now());
    }

    private long daysSince(Appointment appointment) {
        if (appointment.getAppointmentDate() == null) {
            return 0;
        }
        return ChronoUnit.DAYS.between(appointment.getAppointmentDate().toLocalDate(), LocalDate.now());
    }

    private boolean containsAny(String value, String... keywords) {
        for (String keyword : keywords) {
            if (value.contains(normalize(keyword))) {
                return true;
            }
        }
        return false;
    }

    private String normalize(String value) {
        String text = clean(value).toLowerCase(Locale.ROOT);
        String normalized = Normalizer.normalize(text, Normalizer.Form.NFD);
        return normalized.replaceAll("\\p{M}", "").replace('\u0111', 'd');
    }

    private String clean(String value) {
        return value == null ? "" : value.trim();
    }

    private enum ChatIntent {
        GENERAL,
        OIL,
        BRAKE,
        TIRE,
        BOOKING,
        RESCUE,
        HISTORY,
        VEHICLE_SELECTION
    }
}
