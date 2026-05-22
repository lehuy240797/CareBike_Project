package com.carebike.backend.features.auth.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.carebike.backend.features.auth.entity.Role;

@Repository
public interface RoleRepository extends JpaRepository<Role, Integer> {
}