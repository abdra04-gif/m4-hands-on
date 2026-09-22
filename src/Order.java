import java.util.List;

/** A pending order awaiting a quote. */
public record Order(long id, List<Line> lines, boolean expedited,
                    String promoCode) {

    public Order {
        lines = List.copyOf(lines);
    }

    public record Line(String sku, int qty, Money unit) {}
}
