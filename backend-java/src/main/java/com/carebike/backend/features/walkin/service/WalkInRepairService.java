package com.carebike.backend.features.walkin.service;

import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.walkin.dto.WalkInRepairRequest;
import com.carebike.backend.features.walkin.entity.WalkInRepair;
import com.carebike.backend.features.walkin.repository.WalkInRepairRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class WalkInRepairService {

    private final WalkInRepairRepository walkInRepairRepository;
    private final BranchRepository branchRepository;

    public WalkInRepairService(
            WalkInRepairRepository walkInRepairRepository,
            BranchRepository branchRepository) {
        this.walkInRepairRepository = walkInRepairRepository;
        this.branchRepository = branchRepository;
    }

    public List<WalkInRepair> getByBranch(Integer branchId) {
        return walkInRepairRepository.findByBranch_IdOrderByRepairDateDescIdDesc(branchId);
    }

    @Transactional
    public WalkInRepair create(WalkInRepairRequest request) {
        if (request.getBranchId() == null) {
            throw new RuntimeException("Branch is required.");
        }

        Branch branch = branchRepository.findById(request.getBranchId())
                .orElseThrow(() -> new RuntimeException("Branch not found: " + request.getBranchId()));

        WalkInRepair repair = new WalkInRepair();
        repair.setBranch(branch);
        repair.setCustomerName(required(request.getCustomerName(), "Customer name"));
        repair.setCustomerPhone(required(request.getCustomerPhone(), "Customer phone"));
        repair.setVehicleName(required(request.getVehicleName(), "Vehicle name"));
        repair.setVehiclePlate(required(request.getVehiclePlate(), "Vehicle plate"));
        repair.setEngineCapacity(request.getEngineCapacity());
        repair.setCurrentKm(request.getCurrentKm());
        repair.setStaffCode(request.getStaffCode());
        repair.setStaffName(request.getStaffName());
        repair.setInvoiceDetails(request.getInvoiceDetails());
        repair.setTotalCost(request.getTotalCost() != null ? request.getTotalCost() : BigDecimal.ZERO);
        repair.setRepairDate(LocalDateTime.now());
        repair.setStatus("PAYING");

        return walkInRepairRepository.save(repair);
    }

    @Transactional
    public WalkInRepair complete(Integer id) {
        WalkInRepair repair = walkInRepairRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Walk-in repair not found: " + id));
        repair.setStatus("COMPLETED");
        repair.setCompletedAt(LocalDateTime.now());
        return walkInRepairRepository.save(repair);
    }

    private String required(String value, String label) {
        if (value == null || value.isBlank()) {
            throw new RuntimeException(label + " is required.");
        }
        return value.trim();
    }
}
