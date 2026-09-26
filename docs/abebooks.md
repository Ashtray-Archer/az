# AbeBooks + Impact

`bin/abe` turns a book query into the cheapest AbeBooks listing by delivered price and then wraps that listing in AbeBooks' documented Impact affiliate URL.

```sh
mkdir -p ~/.config/az
cp config/abebooks-impact.example ~/.config/az/abebooks-impact
chmod 600 ~/.config/az/abebooks-impact
$EDITOR ~/.config/az/abebooks-impact

# ISBN or title; `find` is optional.
grease bin/abe 9780131457577
grease bin/abe 'Marketing Management'
grease bin/abe find 9780131457577

# Wrap a listing you already have.
grease bin/abe link 'https://www.abebooks.com/servlet/BookDetailsPL?bi=22908240098'
```

The search request uses AbeBooks Search Web Services with:

- `sortorder=17`: total price ascending (book + shipping)
- `destinationcountry=USA` by default
- `currency=USD` by default
- `maxresults=1`
- `outputsize=short`

The command prints one TSV row:

```text
total_price  currency  title  affiliate_url
```

It also records the delivered-price observation in the same append-only `az` price ledger under `www.abebooks.com` / `abebooks-sws`.

## Configuration

`AZ_IMPACT_ID` is the numeric Impact partner ID embedded in the AbeBooks affiliate URL. `AZ_ABEBOOKS_CLIENT_KEY` is the Search Web Services client key. AbeBooks issues the latter separately to affiliates.

No Impact API token is needed for AbeBooks deep links: AbeBooks documents a fixed Impact URL template using the partner ID and an encoded listing URL.

The implementation stays in the Grease/YSH + Unix-tools layer. It uses `curl` for the request and does not introduce Python or Ithon.
