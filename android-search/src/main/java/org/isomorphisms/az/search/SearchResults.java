package org.isomorphisms.az.search;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;

final class SearchResults {
    static final String HEADER = "asin\tamount\tcurrency\tbuy_url\ttitle";

    static final class Item {
        final String asin;
        final String amount;
        final String currency;
        final String buyUrl;
        final String title;

        Item(String asin, String amount, String currency, String buyUrl, String title) {
            this.asin = asin;
            this.amount = amount;
            this.currency = currency;
            this.buyUrl = buyUrl;
            this.title = title;
        }

        Item withPrice(String newAmount, String newCurrency, String newBuyUrl) {
            return new Item(
                    asin,
                    newAmount,
                    newCurrency,
                    newBuyUrl.isEmpty() ? buyUrl : newBuyUrl,
                    title);
        }
    }

    private SearchResults() {
    }

    static List<Item> parseTsv(String text) {
        if (text == null) {
            throw new IllegalArgumentException("search result text is null");
        }

        String normalized = text.replace("\r\n", "\n").replace('\r', '\n');
        String[] lines = normalized.split("\n", -1);
        if (lines.length == 0 || !HEADER.equals(lines[0])) {
            throw new IllegalArgumentException("unexpected az search header");
        }

        ArrayList<Item> items = new ArrayList<>();
        for (int index = 1; index < lines.length; index += 1) {
            String line = lines[index];
            if (line.isEmpty()) {
                continue;
            }

            String[] fields = line.split("\t", -1);
            if (fields.length != 5) {
                throw new IllegalArgumentException(
                        "search result row " + index + " has " + fields.length + " fields");
            }
            if (fields[0].isEmpty()) {
                throw new IllegalArgumentException(
                        "search result row " + index + " has no ASIN");
            }

            items.add(new Item(fields[0], fields[1], fields[2], fields[3], fields[4]));
        }
        return Collections.unmodifiableList(items);
    }

    static List<Item> applyPrice(List<Item> items, String text) {
        if (text == null) {
            throw new IllegalArgumentException("price result text is null");
        }

        String line = text.replace("\r\n", "\n").replace('\r', '\n').trim();
        if (line.isEmpty()) {
            throw new IllegalArgumentException("price result is empty");
        }

        int newline = line.indexOf('\n');
        if (newline >= 0) {
            line = line.substring(0, newline);
        }

        String[] fields = line.split("\t", -1);
        if (fields.length != 5) {
            throw new IllegalArgumentException(
                    "price result has " + fields.length + " fields");
        }

        String asin = fields[1];
        String amount = fields[2];
        String currency = fields[3];
        String buyUrl = fields[4];

        if (asin.isEmpty() || amount.isEmpty()) {
            throw new IllegalArgumentException("price result is missing ASIN or amount");
        }

        ArrayList<Item> updated = new ArrayList<>(items.size());
        boolean matched = false;
        for (Item item : items) {
            if (item.asin.equals(asin)) {
                updated.add(item.withPrice(amount, currency, buyUrl));
                matched = true;
            } else {
                updated.add(item);
            }
        }

        if (!matched) {
            return items;
        }
        return Collections.unmodifiableList(updated);
    }

    static List<Item> filter(List<Item> items, String text) {
        String needle = text == null ? "" : text.trim().toLowerCase(Locale.ROOT);
        if (needle.isEmpty()) {
            return items;
        }

        ArrayList<Item> matches = new ArrayList<>();
        for (Item item : items) {
            if (item.asin.toLowerCase(Locale.ROOT).contains(needle)
                    || item.title.toLowerCase(Locale.ROOT).contains(needle)) {
                matches.add(item);
            }
        }
        return Collections.unmodifiableList(matches);
    }

    static String priceLabel(Item item) {
        if (item.amount.isEmpty()) {
            return "—";
        }
        if ("USD".equals(item.currency)) {
            return "$" + item.amount;
        }
        return item.currency.isEmpty() ? item.amount : item.amount + " " + item.currency;
    }
}
