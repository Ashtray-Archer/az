package org.isomorphisms.az.search;

import java.util.List;

public final class SearchResultsTest {
    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    private static void rejects(String text, String messagePart) {
        try {
            SearchResults.parseTsv(text);
            throw new AssertionError("expected parse rejection");
        } catch (IllegalArgumentException error) {
            require(error.getMessage().contains(messagePart),
                    "wrong rejection: " + error.getMessage());
        }
    }

    public static void main(String[] args) {
        String input = SearchResults.HEADER + "\n"
                + "B012345678\t23.45\tUSD\thttps://example.test/a\tThe C Book\n"
                + "B098765432\t\t\thttps://example.test/b\t\n";
        List<SearchResults.Item> items = SearchResults.parseTsv(input);
        require(items.size() == 2, "expected two parsed rows");
        require("The C Book".equals(items.get(0).title), "title lost");
        require("$23.45".equals(SearchResults.priceLabel(items.get(0))), "USD label wrong");
        require("Price not loaded".equals(SearchResults.priceLabel(items.get(1))),
                "missing-price label wrong");
        require(SearchResults.filter(items, "c book").size() == 1, "title filter wrong");
        require(SearchResults.filter(items, "b098").size() == 1, "ASIN filter wrong");
        require(SearchResults.filter(items, "  ") == items,
                "empty filter should preserve the loaded list");
        rejects("wrong\theader\n", "unexpected az search header");
        rejects(SearchResults.HEADER + "\n\t1\tUSD\thttps://example.test\ttitle\n",
                "has no ASIN");
        rejects(SearchResults.HEADER + "\nB012345678\t1\tUSD\tonly-four\n",
                "has 4 fields");
        System.out.println("ok - SearchResults parser, filter, and price labels");
    }
}
