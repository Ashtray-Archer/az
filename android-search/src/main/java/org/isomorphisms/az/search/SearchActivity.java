package org.isomorphisms.az.search;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayDeque;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class SearchActivity extends Activity {
    public static final String EXTRA_RESULTS_TSV = "org.isomorphisms.az.SEARCH_RESULTS_TSV";
    public static final String EXTRA_QUERY = "org.isomorphisms.az.SEARCH_QUERY";

    private static final String ACTION_TERMUX_SEARCH_RESULT =
            "org.isomorphisms.az.TERMUX_SEARCH_RESULT";
    private static final String ACTION_TERMUX_PRICE_RESULT =
            "org.isomorphisms.az.TERMUX_PRICE_RESULT";
    private static final String EXTRA_ASIN = "org.isomorphisms.az.ASIN";
    private static final String TERMUX_PACKAGE = "com.termux";
    private static final String TERMUX_SERVICE = "com.termux.app.RunCommandService";
    private static final String TERMUX_PERMISSION = "com.termux.permission.RUN_COMMAND";
    private static final String TERMUX_ACTION = "com.termux.RUN_COMMAND";
    private static final String TERMUX_COMMAND_PATH = "com.termux.RUN_COMMAND_PATH";
    private static final String TERMUX_ARGUMENTS = "com.termux.RUN_COMMAND_ARGUMENTS";
    private static final String TERMUX_BACKGROUND = "com.termux.RUN_COMMAND_BACKGROUND";
    private static final String TERMUX_PENDING_INTENT =
            "com.termux.RUN_COMMAND_PENDING_INTENT";
    private static final String TERMUX_COMMAND_LABEL =
            "com.termux.RUN_COMMAND_COMMAND_LABEL";
    private static final String TERMUX_RESULT_BUNDLE = "result";
    private static final String TERMUX_STDOUT = "stdout";
    private static final String TERMUX_STDERR = "stderr";
    private static final String TERMUX_EXIT_CODE = "exitCode";
    private static final String TERMUX_ERR = "err";
    private static final String TERMUX_ERRMSG = "errmsg";
    private static final String AZ_COMMAND_PATH =
            "/data/data/com.termux/files/usr/bin/az";
    private static final int TERMUX_PERMISSION_REQUEST = 7001;
    private static final int MAX_PRICE_JOBS = 3;

    private static final int BG = Color.rgb(20, 18, 24);
    private static final int SURFACE = Color.rgb(33, 31, 38);
    private static final int SURFACE_HIGH = Color.rgb(43, 41, 48);
    private static final int PRIMARY = Color.rgb(208, 188, 255);
    private static final int TEXT = Color.rgb(230, 224, 233);
    private static final int MUTED = Color.rgb(202, 196, 208);
    private static final int OUTLINE = Color.rgb(147, 143, 153);

    private static int nextExecutionId = 1000;

    private EditText search;
    private Button searchButton;
    private EditText filter;
    private TextView sourceLabel;
    private TextView status;
    private LinearLayout results;
    private List<SearchResults.Item> source = Collections.emptyList();
    private final ArrayDeque<String> priceQueue = new ArrayDeque<>();
    private final Set<String> priceInFlight = new HashSet<>();
    private boolean hasLoadedPayload;
    private String pendingQuery;

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

    @Override
    public void onRequestPermissionsResult(
            int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != TERMUX_PERMISSION_REQUEST) {
            return;
        }

        String query = pendingQuery;
        pendingQuery = null;
        if (grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED
                && query != null) {
            runSearch(query);
            return;
        }

        searchButton.setEnabled(true);
        status.setText("Search needs permission to run AZ in Termux");
    }

    private void accept(Intent intent) {
        if (ACTION_TERMUX_SEARCH_RESULT.equals(intent.getAction())) {
            acceptTermuxSearchResult(intent);
            return;
        }
        if (ACTION_TERMUX_PRICE_RESULT.equals(intent.getAction())) {
            acceptTermuxPriceResult(intent);
            return;
        }

        String suppliedQuery = intent.getStringExtra(EXTRA_QUERY);
        if (suppliedQuery != null && !suppliedQuery.trim().isEmpty()) {
            setSearchText(suppliedQuery.trim());
            sourceLabel.setText("Search · " + suppliedQuery.trim());
        } else {
            sourceLabel.setText("No Amazon search loaded");
        }

        source = Collections.emptyList();
        hasLoadedPayload = false;
        priceQueue.clear();
        priceInFlight.clear();
        clearFilter();

        String supplied = suppliedTsv(intent);
        if (supplied != null && !supplied.isEmpty()) {
            load(supplied);
            return;
        }
        render(Collections.emptyList(), "Ready to search",
                "Search Amazon above or send AZ results here");
    }

    private void acceptTermuxSearchResult(Intent intent) {
        searchButton.setEnabled(true);
        String query = intent.getStringExtra(EXTRA_QUERY);
        if (query == null) {
            query = "";
        }
        query = query.trim();
        if (!query.isEmpty()) {
            setSearchText(query);
        }

        Bundle bundle = intent.getBundleExtra(TERMUX_RESULT_BUNDLE);
        if (bundle == null) {
            sourceLabel.setText(query.isEmpty() ? "Search failed" : "Search failed · " + query);
            status.setText("Termux returned no result bundle");
            return;
        }

        int internalError = bundle.getInt(TERMUX_ERR, Activity.RESULT_OK);
        int exitCode = bundle.getInt(TERMUX_EXIT_CODE, 0);
        String stderr = value(bundle.getString(TERMUX_STDERR));
        String errorMessage = value(bundle.getString(TERMUX_ERRMSG));

        if (internalError != Activity.RESULT_OK || exitCode != 0) {
            sourceLabel.setText(query.isEmpty() ? "Search failed" : "Search failed · " + query);
            String detail = firstNonEmpty(stderr, errorMessage);
            status.setText(detail.isEmpty()
                    ? "AZ search failed"
                    : "AZ search failed · " + oneLine(detail));
            return;
        }

        String stdout = value(bundle.getString(TERMUX_STDOUT));
        sourceLabel.setText(query.isEmpty() ? "Amazon search" : "Search · " + query);
        clearFilter();
        load(stdout);
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

        TextView subtitle = text("Amazon search", 13, MUTED);
        subtitle.setPadding(dp(20), 0, dp(20), dp(14));
        root.addView(subtitle, matchWrap());

        LinearLayout searchBox = new LinearLayout(this);
        searchBox.setGravity(Gravity.CENTER_VERTICAL);
        searchBox.setPadding(dp(18), dp(6), dp(6), dp(6));
        searchBox.setMinimumHeight(dp(60));
        searchBox.setBackground(box(SURFACE_HIGH, 30, OUTLINE));

        search = new EditText(this);
        search.setSingleLine(true);
        search.setHint("Search Amazon");
        search.setHintTextColor(MUTED);
        search.setTextColor(TEXT);
        search.setTextSize(16);
        search.setImeOptions(EditorInfo.IME_ACTION_SEARCH);
        search.setBackgroundColor(Color.TRANSPARENT);
        search.setOnEditorActionListener((view, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                submitSearch();
                return true;
            }
            return false;
        });
        searchBox.addView(search, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.MATCH_PARENT, 1));

        searchButton = button("Search", PRIMARY, BG);
        searchButton.setOnClickListener(view -> submitSearch());
        searchBox.addView(searchButton);

        LinearLayout.LayoutParams searchLayout = matchWrap();
        searchLayout.setMargins(dp(16), 0, dp(16), dp(10));
        root.addView(searchBox, searchLayout);

        sourceLabel = text("No Amazon search loaded", 13, MUTED);
        sourceLabel.setPadding(dp(20), 0, dp(20), dp(10));
        root.addView(sourceLabel, matchWrap());

        LinearLayout filterBox = new LinearLayout(this);
        filterBox.setGravity(Gravity.CENTER_VERTICAL);
        filterBox.setPadding(dp(18), dp(4), dp(6), dp(4));
        filterBox.setMinimumHeight(dp(52));
        filterBox.setBackground(box(SURFACE, 26, OUTLINE));

        filter = new EditText(this);
        filter.setSingleLine(true);
        filter.setHint("Filter loaded results");
        filter.setHintTextColor(MUTED);
        filter.setTextColor(TEXT);
        filter.setTextSize(14);
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
        filterLayout.setMargins(dp(16), 0, dp(16), dp(10));
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

    private void submitSearch() {
        String query = search.getText().toString().trim();
        if (query.isEmpty()) {
            status.setText("Enter something to search for");
            return;
        }

        if (checkSelfPermission(TERMUX_PERMISSION) != PackageManager.PERMISSION_GRANTED) {
            pendingQuery = query;
            requestPermissions(new String[]{TERMUX_PERMISSION}, TERMUX_PERMISSION_REQUEST);
            return;
        }

        runSearch(query);
    }

    private void runSearch(String query) {
        pendingQuery = null;
        searchButton.setEnabled(false);
        sourceLabel.setText("Search · " + query);
        status.setText("—");

        priceQueue.clear();
        priceInFlight.clear();

        Intent resultIntent = new Intent(this, SearchActivity.class);
        resultIntent.setAction(ACTION_TERMUX_SEARCH_RESULT);
        resultIntent.putExtra(EXTRA_QUERY, query);
        resultIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        int requestCode;
        synchronized (SearchActivity.class) {
            requestCode = nextExecutionId++;
        }

        int flags = PendingIntent.FLAG_ONE_SHOT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags |= PendingIntent.FLAG_MUTABLE;
        }
        PendingIntent pendingIntent =
                PendingIntent.getActivity(this, requestCode, resultIntent, flags);

        Intent command = new Intent();
        command.setClassName(TERMUX_PACKAGE, TERMUX_SERVICE);
        command.setAction(TERMUX_ACTION);
        command.putExtra(TERMUX_COMMAND_PATH, AZ_COMMAND_PATH);
        command.putExtra(TERMUX_ARGUMENTS, new String[]{"search", query});
        command.putExtra(TERMUX_BACKGROUND, true);
        command.putExtra(TERMUX_PENDING_INTENT, pendingIntent);
        command.putExtra(TERMUX_COMMAND_LABEL, "AZ Amazon search");

        try {
            if (startService(command) == null) {
                searchButton.setEnabled(true);
                sourceLabel.setText("Search unavailable · " + query);
                status.setText("Termux RunCommandService was not found");
            }
        } catch (SecurityException error) {
            searchButton.setEnabled(true);
            sourceLabel.setText("Search unavailable · " + query);
            status.setText("Termux has not allowed AZ Search to run commands");
        } catch (RuntimeException error) {
            searchButton.setEnabled(true);
            sourceLabel.setText("Search unavailable · " + query);
            status.setText("Could not start AZ search through Termux");
        }
    }

    private void load(String tsv) {
        try {
            source = SearchResults.parseTsv(tsv);
            hasLoadedPayload = true;
            renderFiltered();
            enqueueMissingPrices();
        } catch (IllegalArgumentException error) {
            source = Collections.emptyList();
            hasLoadedPayload = true;
            render(source, "Could not parse AZ search results", "No products to show");
            Toast.makeText(this, error.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private void enqueueMissingPrices() {
        priceQueue.clear();
        priceInFlight.clear();
        for (SearchResults.Item item : source) {
            if (item.amount.isEmpty()) {
                priceQueue.addLast(item.asin);
            }
        }
        pumpPriceQueue();
    }

    private void pumpPriceQueue() {
        while (priceInFlight.size() < MAX_PRICE_JOBS && !priceQueue.isEmpty()) {
            String asin = priceQueue.removeFirst();
            if (priceInFlight.add(asin)) {
                startPriceLookup(asin);
            }
        }
    }

    private void startPriceLookup(String asin) {
        Intent resultIntent = new Intent(this, SearchActivity.class);
        resultIntent.setAction(ACTION_TERMUX_PRICE_RESULT);
        resultIntent.putExtra(EXTRA_ASIN, asin);
        resultIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        int requestCode;
        synchronized (SearchActivity.class) {
            requestCode = nextExecutionId++;
        }

        int flags = PendingIntent.FLAG_ONE_SHOT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags |= PendingIntent.FLAG_MUTABLE;
        }
        PendingIntent pendingIntent =
                PendingIntent.getActivity(this, requestCode, resultIntent, flags);

        Intent command = new Intent();
        command.setClassName(TERMUX_PACKAGE, TERMUX_SERVICE);
        command.setAction(TERMUX_ACTION);
        command.putExtra(TERMUX_COMMAND_PATH, AZ_COMMAND_PATH);
        command.putExtra(TERMUX_ARGUMENTS, new String[]{"price", asin});
        command.putExtra(TERMUX_BACKGROUND, true);
        command.putExtra(TERMUX_PENDING_INTENT, pendingIntent);
        command.putExtra(TERMUX_COMMAND_LABEL, "AZ Amazon price");

        try {
            if (startService(command) == null) {
                finishPriceLookup(asin);
            }
        } catch (RuntimeException error) {
            finishPriceLookup(asin);
        }
    }

    private void acceptTermuxPriceResult(Intent intent) {
        String asin = value(intent.getStringExtra(EXTRA_ASIN));
        Bundle bundle = intent.getBundleExtra(TERMUX_RESULT_BUNDLE);

        if (bundle != null) {
            int internalError = bundle.getInt(TERMUX_ERR, Activity.RESULT_OK);
            int exitCode = bundle.getInt(TERMUX_EXIT_CODE, 0);
            if (internalError == Activity.RESULT_OK && exitCode == 0) {
                String stdout = value(bundle.getString(TERMUX_STDOUT));
                try {
                    source = SearchResults.applyPrice(source, stdout);
                    renderFiltered();
                } catch (IllegalArgumentException ignored) {
                    // Leave the quiet dash in place. A later event may retry.
                }
            }
        }

        finishPriceLookup(asin);
    }

    private void finishPriceLookup(String asin) {
        if (!asin.isEmpty()) {
            priceInFlight.remove(asin);
        }
        pumpPriceQueue();
    }

    private void renderFiltered() {
        if (status == null || results == null) {
            return;
        }
        if (!hasLoadedPayload) {
            render(Collections.emptyList(), "Ready to search",
                    "Search Amazon above or send AZ results here");
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

    private void setSearchText(String query) {
        if (!query.contentEquals(search.getText())) {
            search.setText(query);
            search.setSelection(search.length());
        }
    }

    private void clearFilter() {
        if (filter.getText().length() != 0) {
            filter.setText("");
        }
    }

    private String value(String text) {
        return text == null ? "" : text;
    }

    private String firstNonEmpty(String first, String second) {
        return first.isEmpty() ? second : first;
    }

    private String oneLine(String text) {
        return text.replace('\r', ' ').replace('\n', ' ').trim();
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
