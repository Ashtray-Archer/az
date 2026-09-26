# Zillow API surface

Snapshot: 2026-09-17

This file inventories the complete set of named offerings currently exposed by
Zillow Group's public Data & APIs portal. It records interface facts and source
locations; it does not imply that partner-only or invite-only interfaces are
available to this repository.

Portal root: <https://www.zillowgroup.com/developers/>

## Agents

### Agent Reviews

- Portal: <https://www.zillowgroup.com/developers/api/agents/agent-reviews/>
- Implementation surface: Bridge Interactive Platform
- Documentation: <https://bridgedataoutput.com/docs/platform/API/zg-data#agent-reviews>
- Access: Bridge account plus Zillow Agent Reviews dataset approval
- Authentication: API key / Bridge access token
- Requests: URI query style
- Responses: JSON
- Purpose: receive and manage Zillow Group listing reviews, including review notifications, bulk retrieval, and responses

## MLS & Broker Listings

### MLS Listings

- Portal: <https://www.zillowgroup.com/developers/api/mls-broker-data/mls-listings/>
- Implementation surface: Bridge Listing Output
- Documentation: <https://rets.ly/docs>
- Access: invite only; MLS availability depends on the individual MLS partner
- Authentication: password plus access token
- Architecture: REST
- Requests: URI query string
- Responses: JSON normalized to the RESO data dictionary

### Reviews API

- Portal: <https://www.zillowgroup.com/developers/api/mls-broker-data/reviews-api/>
- Implementation surface: Bridge Interactive Platform
- Documentation: <https://bridgedataoutput.com/docs/platform/API/zg-data#agent-reviews>
- Access: Bridge account plus Zillow Agent Reviews dataset approval
- Responses: JSON
- Purpose: the same Zillow reviews family exposed from the MLS/Broker section

## Mortgage

### Get Current Rates / Historical Rates

- Portal: <https://www.zillowgroup.com/developers/api/mortgage/get-current-rates/>
- Historical-rate documentation: <https://mortgageapi.zillow.com/api/getRates>
- Current-rate documentation: <https://mortgageapi.zillow.com/api/getCurrentRates>
- Historical request endpoint: `GET https://mortgageapi.zillow.com/getRates`
- Current request endpoint: `GET https://mortgageapi.zillow.com/getCurrentRates`
- Authentication: no bearer credential is described, but an authorized `partnerId` is required
- Responses: JSON
- `getRates` controls include query groups, a date window, current-rate inclusion, aggregation, and gap filling
- `getCurrentRates` accepts the same typed rate-query dictionary but returns current-rate results only
- The typed query surface includes refinance/purchase, state or ZIP/property bucket, loan program, loan type, loan amount, loan-to-value, and credit-score buckets

### Lender Reviews

- Portal: <https://www.zillowgroup.com/developers/api/mortgage/zillow-lender-reviews/>
- Documentation: <https://mortgageapi.zillow.com/api/zillowLenderReviews>
- Request endpoint: `GET https://mortgageapi.zillow.com/zillowLenderReviews`
- Authentication: authorized `partnerId` required
- Required lender key: NMLS ID; institutional lenders also use company name
- Responses: JSON
- Result includes lender profile/review URLs, aggregate rating/count, and up to ten recent reviews

### Prospect Sync API

- Portal: <https://www.zillowgroup.com/developers/api/mortgage/prospect-sync-api/>
- Product family: Mortech
- Access: partner/MSA
- Authentication: third-party name plus license key
- Architecture: read/write
- Requests: HTTP POST
- Responses: XML
- Purpose: exchange prospect pricing activity and related updates with third-party systems

### Prospect Trigger API

- Portal: <https://www.zillowgroup.com/developers/api/mortgage/prospect-trigger-api/>
- Product family: Mortech
- Access: partner/MSA
- Authentication: third-party name plus license key
- Architecture: read/write
- Response format: configurable
- Purpose: send lead/rate/trigger events to third-party systems such as CRMs

### Rate Cloud API

- Portal: <https://www.zillowgroup.com/developers/api/mortgage/rate-cloud-api/>
- Product family: Mortech
- Access: partner
- Authentication: third-party name plus license key
- Architecture: read-only
- Requests: HTTP POST
- Responses: JSON
- Purpose: submit loan criteria and receive lender pricing

### LOS Plug-In Integration API

- Portal: <https://www.zillowgroup.com/developers/api/mortgage/los-plug-in-integration-api/>
- Product family: Mortech
- Access: partner/MSA
- Authentication: third-party name plus license key
- Portal metadata lists an iFrame architecture, HTTP POST requests, and XML responses; the description also mentions REST integration or embedding the Mortech UI with SSO

### Lead Posting API

- Portal: <https://www.zillowgroup.com/developers/api/mortgage/lead-posting-api/>
- Product family: Mortech
- Authentication: third-party name plus license key
- Architecture: read/write
- Requests: HTTP POST
- Responses: XML
- Purpose: submit prospects for pricing and lead routing

### 3rd Party Administration Guide

- Portal: <https://www.zillowgroup.com/developers/api/mortgage/3rd-party-administration-guide/>
- Product family: Mortech
- Access: partner/MSA
- Authentication: third-party name plus license key
- Architecture: read/write
- Requests: HTTP POST
- Responses: XML
- Purpose: retrieve and update prospect statuses in the Mortech pricing pipeline

### 3rd Party Integration Guide

- Portal: <https://www.zillowgroup.com/developers/api/mortgage/3rd-party-integration-guide/>
- Product family: Mortech
- Access: partner/MSA
- Authentication: third-party name plus license key
- Architecture: read-only
- Requests: HTTP POST
- Responses: XML
- Purpose: embed Mortech pricing-engine functionality in third-party interfaces

## Public Data

### Public Records

- Portal: <https://www.zillowgroup.com/developers/api/public-data/public-records-api/>
- Implementation surface: Bridge Public Records API
- Documentation: <https://bridgedataoutput.com/docs/platform/#parcels>
- Access: invite only; described primarily for commercial use
- Authentication: password plus access token
- Architecture: REST
- Requests: URI query string
- Responses: JSON
- Data family: parcel, assessment, and county transaction records across the US

### Neighborhood Data

- Portal: <https://www.zillowgroup.com/developers/api/public-data/neighborhood-data/>
- Current delivery surface: Zillow Research downloads
- Documentation/data: <https://www.zillow.com/research/data/>
- Format: CSV
- Access: public download

### Real Estate Metrics

- Portal: <https://www.zillowgroup.com/developers/api/public-data/real-estate-metrics/>
- Documentation/data: <https://www.zillow.com/research/data/>
- Architecture: download rather than request/response API
- Format: CSV
- Geography includes neighborhood, ZIP, city, county, metro, state, and national datasets depending on metric
- Zillow requires attribution for use of these data

## Rentals

### Rentals Feed Integrations

- Portal: <https://www.zillowgroup.com/developers/api/rentals/rentals-feed-integrations/>
- Access: integration approval and testing required
- Primary input: Zillow Rental Listings XML feed
- Alternative input: MITS format
- Zillow also advertises a real-time syndication layer
- Portal-linked bulk-feed guide: <https://s3.amazonaws.com/files.hotpads.com/%2Bguides/Rental%2BListing%2BBulk%2BFeed%2BGuide.pdf>
- MITS source: <https://rettc.org/mits-data-models>
- Portal-linked real-time guide: <https://s3.amazonaws.com/files.hotpads.com/%2Bguides/Rental%2BListing%2BReal-Time%2BListing%2BGuide.pdf>

### Lead API

- Portal: <https://www.zillowgroup.com/developers/api/rentals/lead-api/>
- Delivery direction: Zillow Rental Network posts leads to a CRM/operator webhook
- Transport: HTTP POST callback
- Payload: URL-encoded fields
- Integration/testing is coordinated with Zillow Rentals
- Portal-linked guide: <https://s3.amazonaws.com/files.hotpads.com/%2Bguides/Lead%2BAPI%2BGuide.pdf>

## Transactions

### Transaction Management

- Portal: <https://www.zillowgroup.com/developers/api/transactions/transaction-management/>
- Implementation surface: dotloop Public API v2
- Documentation: <https://dotloop.github.io/public-api/>
- Authentication: OAuth 2.0, three-legged flow
- Architecture: REST
- Operations: CRUD-style resources
- Responses: JSON unless a resource documents otherwise
- Main resource families include profiles, loops/transactions, contacts, and authentication/integration support

## Zestimate

### Zestimates

- Portal: <https://www.zillowgroup.com/developers/api/zestimate/zestimates-api/>
- Implementation surface: Bridge
- Documentation: <https://bridgedataoutput.com/docs/platform/#zestimates>
- Access: request/invite path; described primarily for commercial use
- Authentication: password plus access token
- Architecture: REST
- Requests: URI query string
- Responses: JSON
- Data family: property, rental, and foreclosure Zestimate values

## Legacy Zillow API material

Zillow still hosts older API terms describing the historical ZWSID-based Zillow
API family (home valuation, property details, mortgage, postings, reviews, and
directory calls):

<https://www.zillowgroup.com/developers/terms/>

That material is retained as historical context only. The current Data & APIs
portal above is the inventory used for new `az` work unless a live current
Zillow page explicitly points back to a legacy endpoint.

## Local source mirror

`docs/zillow/mirror-sources.tsv` contains the complete current portal inventory
plus the public documentation targets linked from it. Run:

```sh
grease bin/zillow_mirror_documentation
```

The command writes fetched source pages under `.cache/zillow-documentation/`,
which is ignored by Git. Entries marked `linked-blocked` remain in the manifest
as provenance but are not fetched automatically.
