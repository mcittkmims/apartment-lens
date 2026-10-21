package md.apartmentlens.geodata;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Text helpers for names of streets and places in Romanian and Russian. A copy of the scraper's
 * {@code text.Text}, trimmed to what the imports use; keep the two in step.
 */
public final class Text {

    private static final Pattern CONTROL = Pattern.compile("[\\p{Cc}&&[^\\n\\t]]|[\\u200B-\\u200F\\u2060\\uFEFF]");
    private static final Pattern SPACES = Pattern.compile("[\\s\\u00A0\\u2007\\u202F]+");
    private static final Pattern MARKS = Pattern.compile("\\p{M}+");
    private static final Pattern CYRILLIC = Pattern.compile("\\p{IsCyrillic}");
    private static final Pattern LATIN = Pattern.compile("\\p{IsLatin}");
    private static final Pattern NON_KEY = Pattern.compile("[^\\p{L}\\p{N}]+");

    private Text() {
    }

    /** Trims, removes invisible characters and collapses all whitespace to single spaces. Null for blank text. */
    public static String clean(String s) {
        if (s == null) {
            return null;
        }
        String out = SPACES.matcher(CONTROL.matcher(s).replaceAll("")).replaceAll(" ").strip();
        return out.isEmpty() ? null : fixDiacritics(out);
    }

    /**
     * Replaces the cedilla letters (ş ţ), which keyboards often produce, with the correct Romanian
     * comma-below letters (ș ț), and the old-orthography tilde forms.
     */
    public static String fixDiacritics(String s) {
        if (s == null) {
            return null;
        }
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            sb.append(switch (c) {
                case 'ş' -> 'ș'; // ş -> ș
                case 'Ş' -> 'Ș'; // Ş -> Ș
                case 'ţ' -> 'ț'; // ţ -> ț
                case 'Ţ' -> 'Ț'; // Ţ -> Ț
                case 'ã' -> 'ă'; // ã -> ă
                case 'Ã' -> 'Ă'; // Ã -> Ă
                default -> c;
            });
        }
        return sb.toString();
    }

    /**
     * A comparison key: lower case, no diacritics, letters and digits separated by single spaces.
     * "Ștefan cel Mare și Sfânt", "Ștefan cel Mare și Sfînt" and "stefan cel mare si sfant" give the same key.
     */
    public static String fold(String s) {
        if (s == null) {
            return "";
        }
        // â and î are one letter in two spellings ("Râșcani", "Rîșcani"; "Sfânt", "Sfînt"). Both fold to "a",
        // as sellers who skip diacritics write "Batran" and "Hancesti"; Russian ы also maps to "a".
        String lower = fixDiacritics(s).toLowerCase(Locale.ROOT).replace('ё', 'е').replace('î', 'â');
        // Keep й: in Russian it is a different letter, not и with a mark.
        lower = lower.replace('й', '\u0001');
        String stripped = MARKS.matcher(Normalizer.normalize(lower, Normalizer.Form.NFD)).replaceAll("");
        stripped = stripped.replace('\u0001', 'й');
        return unmixScripts(NON_KEY.matcher(stripped).replaceAll(" ").strip());
    }

    private static final String LATIN_LOOKALIKES = "aceopxykmthbi";
    private static final String CYRILLIC_LOOKALIKES = "асеорхукмтнві";

    /**
     * Words typed with letters from both alphabets ("Cерый" with a Latin C, "Каля Eшилор") are rewritten
     * in the alphabet most of their letters use, so they compare equal to the correct spelling.
     */
    static String unmixScripts(String key) {
        if (!hasCyrillic(key) || !hasLatin(key)) {
            return key;
        }
        StringBuilder out = new StringBuilder(key.length());
        for (String word : key.split(" ", -1)) {
            long cyr = word.chars().filter(c -> Character.UnicodeScript.of(c) == Character.UnicodeScript.CYRILLIC).count();
            long lat = word.chars().filter(c -> Character.UnicodeScript.of(c) == Character.UnicodeScript.LATIN).count();
            String from = cyr >= lat ? LATIN_LOOKALIKES : CYRILLIC_LOOKALIKES;
            String to = cyr >= lat ? CYRILLIC_LOOKALIKES : LATIN_LOOKALIKES;
            if (!out.isEmpty()) {
                out.append(' ');
            }
            if (cyr == 0 || lat == 0) {
                out.append(word);
                continue;
            }
            for (char c : word.toCharArray()) {
                int i = from.indexOf(c);
                out.append(i >= 0 ? to.charAt(i) : c);
            }
        }
        return out.toString();
    }

    public static boolean hasCyrillic(String s) {
        return s != null && CYRILLIC.matcher(s).find();
    }

    public static boolean hasLatin(String s) {
        return s != null && LATIN.matcher(s).find();
    }
}
