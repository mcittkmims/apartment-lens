package md.apartmentlens.geodata;

import java.time.Clock;
import java.time.Duration;
import java.util.List;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.json.JsonMapper;

/**
 * Loads the reference data of streets, house numbers and places into the {@code ref} schema, then exits:
 * <ul>
 *   <li>{@code cadastre}: the cadastre's public layers from geodata.gov.md</li>
 *   <li>{@code osm}: links the OpenStreetMap staging tables (loaded by osm2pgsql, see refresh.sh) to the
 *       cadastre; run after {@code cadastre}, which drops the links</li>
 * </ul>
 * Each replaces its own source's rows in one transaction; a failed import keeps the previous data.
 */
@SpringBootApplication
public class GeodataApplication {

    static final List<String> COMMANDS = List.of("cadastre", "osm");

    public static void main(String[] args) {
        List<String> commands = List.of(args).stream().filter(a -> !a.startsWith("--")).toList();
        if (commands.isEmpty() || !COMMANDS.containsAll(commands)) {
            System.err.println("usage: geodata cadastre | osm (run refresh.sh for the whole refresh)");
            System.exit(2);
        }
        System.exit(SpringApplication.exit(SpringApplication.run(GeodataApplication.class, args)));
    }

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    RefStore refStore(JdbcClient jdbc, JdbcTemplate template) {
        return new RefStore(jdbc, template);
    }

    @Bean
    CadastreImporter cadastreImporter(JsonMapper json, RefStore store, TransactionTemplate tx, Clock clock,
                                      @Value("${geodata.user-agent:apartment-lens-geodata/1.0 (+https://github.com/mcittkmims/apartment-lens)}")
                                      String userAgent) {
        PoliteHttpClient http = new PoliteHttpClient(userAgent, Duration.ofSeconds(1), 6, Duration.ofSeconds(180));
        return new CadastreImporter(http, json, store, tx, clock);
    }

    @Bean
    OsmImporter osmImporter(JdbcClient jdbc, JdbcTemplate template, RefStore store, TransactionTemplate tx, Clock clock) {
        return new OsmImporter(jdbc, template, store, tx, clock);
    }

    @Bean
    ApplicationRunner commands(CadastreImporter cadastre, OsmImporter osm, JdbcClient jdbc) {
        return (ApplicationArguments args) -> {
            List<String> commands = args.getNonOptionArgs();
            if (commands.contains("cadastre")) {
                cadastre.run();
            }
            if (commands.contains("osm")) {
                boolean staged = jdbc.sql("select to_regclass('ref.osm_way') is not null").query(Boolean.class).single();
                if (staged) {
                    osm.run(); // after the cadastre: links its streets to the cadastre's
                } else {
                    LoggerFactory.getLogger(GeodataApplication.class)
                            .warn("no OpenStreetMap staging tables yet: run the whole refresh (refresh.sh)");
                }
            }
        };
    }
}
