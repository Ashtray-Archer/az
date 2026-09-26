package org.isomorphisms.az.search;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.Collections;
import java.util.List;

public final class SearchActivity extends Activity {
    public static final String EXTRA_RESULTS_TSV = "org.isomorphisms.az.SEARCH_RESULTS_TSV";
    public static final String EXTRA_QUERY = "org.isomorphisms.az.SEARCH_QUERY";

    private static final int BG = Color.rgb(20, 18, 24);
    private static final int SURFACE = Color.rgb(33, 31, 38);
    private static final int SURFACE_HIGH = Color.rgb(43, 41, 48);
    private static final int PRIMARY = Color.rgb(208, 188, 255);
    private static final int TEXT = Color.rgb(230, 224, 233);
    private static final int MUTED = Color.rgb(202, 196, 208);
    private static final int OUTLINE = Color.rgb(147, 143, 153);

    private EditText filter;
    private TextView sourceLabel;
    private TextView status;
    private LinearLayout results;
    private List<SearchResults.Item> source = Collections.emptyList();
    private boolean hasLoadedPayload;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        setContentView(screen());
        accept(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        accept(intent);
    }

    private void accept(Intent intent) {
        String suppliedQuery = intent.getStringExtra(EXTRA_QUERY);
        if (suppliedQuery == null || suppliedQuery.trim().isEmpty()) {
            sourceLabel.setText("Amazon product search");
        } else {
            sourceLabel.setText("Search · " + suppliedQuery.trim());
        }

        source = Collections.emptyList();
        hasLoadedPayload = false;
        if (filter.getText().length() != 0) {
            filter.setText("");
        }

        String supplied = suppliedTsv(intent);
        if (supplied != null && !supplied.isEmpty()) {
            load(supplied);
            return;
        }
        render(Collections.emptyList(), "No results loaded",
                "Run AZ search and send the results here");
    }

    private String suppliedTsv(Intent intent) {
        String supplied = intent.getStringExtra(EXTRA_RESULTS_TSV);
        if ((supplied == null || supplied.isEmpty())
                && Intent.ACTION_SEND.equals(intent.getAction())
                && "text/plain".equals(intent.getType())) {
            supplied = intent.getStringExtra(Intent.EXTRA_TEXT);
        }
        return supplied;
    }

    private View screen() {
        LinearLayout root = column();
        root.setBackgroundColor(BG);

        TextView title = text("AZ", 28, TEXT);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        title.setPadding(dp(20), dp(18), dp(20), dp(2));
        root.addView(title, matchWrap());

        sourceLabel = text("Amazon product search", 14, MUTED);
        sourceLabel.setPadding(dp(20), 0, dp(20), dp(14));
        root.addView(sourceLabel, matchWrap());

        LinearLayout filterBox = new LinearLayout(this);
        filterBox.setGravity(Gravity.CENTER_VERTICAL);
        filterBox.setPadding(dp(18), dp(6), dp(6), dp(6));
        filterBox.setMinimumHeight(dp(60));
        filterBox.setBackground(box(SURFACE_HIGH, 30, OUTLINE));

        filter = new EditText(this);
        filter.setSingleLine(true);
        filter.setHint("Filter these results");
        filter.setHintTextColor(MUTED);
        filter.setTextColor(TEXT);
        filter.setTextSize(16);
        filter.setBackgroundColor(Color.TRANSPARENT);
        filter.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence text, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence text, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable text) {
                renderFiltered();
            }
        });
        filterBox.addView(filter, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.MATCH_PARENT, 1));

        Button clear = button("Clear", SURFACE_HIGH, PRIMARY);
        clear.setOnClickListener(view -> filter.setText(""));
        filterBox.addView(clear);

        LinearLayout.LayoutParams filterLayout = matchWrap();
        filterLayout.setMargins(dp(16), 0, dp(16), dp(12));
        root.addView(filterBox, filterLayout);

        status = text("", 12, MUTED);
        status.setPadding(dp(20), 0, dp(20), dp(10));
        status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        root.addView(status, matchWrap());

        ScrollView scroll = new ScrollView(this);
        results = column();
        results.setPadding(dp(16), 0, dp(16), dp(24));
        scroll.addView(results, matchWrap());
        root.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        return root;
    }

    private void load(String tsv) {
        try {
            source = SearchResults.parseTsv(tsv);
            hasLoadedPayload = true;
            renderFiltered();
        } catch (IllegalArgumentException error) {
            source = Collections.emptyList();
            hasLoadedPayload = true;
            render(source, "Could not parse AZ search results", "No products to show");
            Toast.makeText(this, error.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private void renderFiltered() {
        if (status == null || results == null) {
            return;
        }
        if (!hasLoadedPayload) {
            render(Collections.emptyList(), "No results loaded",
                    "Run AZ search and send the results here");
            return;
        }

        String needle = filter.getText().toString().trim();
        List<SearchResults.Item> visible = SearchResults.filter(source, needle);
        if (needle.isEmpty()) {
            String label = source.size() == 1 ? "1 loaded result" : source.size() + " loaded results";
            render(visible, label, "No Amazon products found");
        } else {
            render(visible, visible.size() + " of " + source.size() + " results",
                    "No loaded products match this filter");
        }
    }

    private void render(List<SearchResults.Item> items, String label, String emptyLabel) {
        status.setText(label);
        results.removeAllViews();
        if (items.isEmpty()) {
            TextView empty = text(emptyLabel, 16, MUTED);
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(dp(18), dp(56), dp(18), dp(56));
            results.addView(empty, matchWrap());
            return;
        }
        for (SearchResults.Item item : items) {
            LinearLayout.LayoutParams layout = matchWrap();
            layout.bottomMargin = dp(12);
            results.addView(card(item), layout);
        }
    }

    private View card(SearchResults.Item item) {
        LinearLayout card = column();
        card.setPadding(dp(18), dp(17), dp(18), dp(16));
        card.setBackground(box(SURFACE, 20, -1));
        card.setElevation(dp(1));

        TextView name = text(item.title.isEmpty() ? "Amazon product" : item.title, 17, TEXT);
        name.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        card.addView(name, matchWrap());

        TextView asin = text("ASIN " + item.asin, 12, MUTED);
        LinearLayout.LayoutParams asinLayout = matchWrap();
        asinLayout.topMargin = dp(6);
        card.addView(asin, asinLayout);

        boolean hasPrice = !item.amount.isEmpty();
        TextView price = text(SearchResults.priceLabel(item), hasPrice ? 21 : 14,
                hasPrice ? PRIMARY : MUTED);
        if (hasPrice) {
            price.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        }
        LinearLayout.LayoutParams priceLayout = matchWrap();
        priceLayout.topMargin = dp(12);
        card.addView(price, priceLayout);

        if (httpUrl(item.buyUrl)) {
            Button open = button("Open Amazon", SURFACE_HIGH, PRIMARY);
            open.setOnClickListener(view -> open(item.buyUrl));
            LinearLayout.LayoutParams openLayout = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            openLayout.topMargin = dp(16);
            card.addView(open, openLayout);
        } else {
            TextView missing = text("Product link not loaded", 12, MUTED);
            LinearLayout.LayoutParams missingLayout = matchWrap();
            missingLayout.topMargin = dp(12);
            card.addView(missing, missingLayout);
        }
        return card;
    }

    private boolean httpUrl(String url) {
        return url != null && (url.startsWith("https://") || url.startsWith("http://"));
    }

    private void open(String url) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (ActivityNotFoundException error) {
            Toast.makeText(this, "No browser can open this product link", Toast.LENGTH_SHORT).show();
        }
    }

    private LinearLayout column() {
        LinearLayout view = new LinearLayout(this);
        view.setOrientation(LinearLayout.VERTICAL);
        return view;
    }

    private TextView text(String value, float size, int color) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        view.setIncludeFontPadding(false);
        return view;
    }

    private Button button(String label, int background, int foreground) {
        Button view = new Button(this);
        view.setText(label);
        view.setTextSize(14);
        view.setTextColor(foreground);
        view.setAllCaps(false);
        view.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        view.setGravity(Gravity.CENTER);
        view.setMinHeight(dp(48));
        view.setMinWidth(dp(48));
        view.setPadding(dp(16), dp(8), dp(16), dp(8));
        view.setBackground(box(background, 24, -1));
        return view;
    }

    private GradientDrawable box(int color, int radius, int stroke) {
        GradientDrawable shape = new GradientDrawable();
        shape.setColor(color);
        shape.setCornerRadius(dp(radius));
        if (stroke >= 0) {
            shape.setStroke(dp(1), stroke);
        }
        return shape;
    }

    private LinearLayout.LayoutParams matchWrap() {
        return new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
