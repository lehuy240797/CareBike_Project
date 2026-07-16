package com.carebike.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import com.carebike.backend.features.auth.repository.UserRepository;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

@SpringBootTest
class UnicodeDatabaseIntegrationTests {

    private static final String VIETNAMESE_SAMPLE =
            "Xe kh\u00F4ng kh\u1EDFi \u0111\u1ED9ng \u2013 \u0110\u1EAFk L\u1EAFk, b\u1EA3o d\u01B0\u1EE1ng \u0111\u1ECBnh k\u1EF3";

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private UserRepository userRepository;

    @Test
    void unicodeStringRoundTripsThroughSqlServerParameter() {
        String actual = jdbcTemplate.queryForObject(
                "SELECT CAST(? AS NVARCHAR(MAX))",
                String.class,
                VIETNAMESE_SAMPLE
        );

        assertThat(actual).isEqualTo(VIETNAMESE_SAMPLE);
    }

    @Test
    void mixedVarcharAndNvarcharEntityMappingLoadsExistingUsers() {
        assertThatCode(() -> userRepository.findAll())
                .doesNotThrowAnyException();
    }

    @Test
    void businessTextColumnsUseUnicodeSqlServerTypes() {
        List<String> nonUnicodeColumns = jdbcTemplate.query(
                """
                SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = 'dbo'
                  AND (
                    (TABLE_NAME = 'appointments' AND COLUMN_NAME IN ('note', 'invoice_details'))
                    OR (TABLE_NAME = 'branches' AND COLUMN_NAME IN ('name', 'address'))
                    OR (TABLE_NAME = 'categories' AND COLUMN_NAME IN ('name', 'description'))
                    OR (TABLE_NAME = 'maintenance_history' AND COLUMN_NAME = 'service_details')
                    OR (TABLE_NAME = 'rescues' AND COLUMN_NAME IN ('issue_description', 'invoice_details'))
                    OR (TABLE_NAME = 'spare_parts' AND COLUMN_NAME IN ('name', 'description'))
                    OR (TABLE_NAME = 'staffs' AND COLUMN_NAME = 'full_name')
                    OR (TABLE_NAME = 'users' AND COLUMN_NAME IN ('full_name', 'gender'))
                    OR (TABLE_NAME = 'vehicles' AND COLUMN_NAME IN ('brand', 'vehicle_name'))
                    OR (TABLE_NAME = 'walk_in_repairs'
                        AND COLUMN_NAME IN ('customer_name', 'vehicle_name', 'staff_name', 'invoice_details'))
                  )
                  AND DATA_TYPE IN ('varchar', 'char', 'text')
                ORDER BY TABLE_NAME, ORDINAL_POSITION
                """,
                (resultSet, rowNumber) -> String.format(
                        "%s.%s (%s)",
                        resultSet.getString("TABLE_NAME"),
                        resultSet.getString("COLUMN_NAME"),
                        resultSet.getString("DATA_TYPE")
                )
        );

        assertThat(nonUnicodeColumns)
                .as("All business text columns must use NVARCHAR/NCHAR")
                .isEmpty();
    }
}
