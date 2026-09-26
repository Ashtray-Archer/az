# Inspectable SMS service state

`bin/idric_sms_service` is the filesystem service runner for `Network.SMS` in
Idric-Net. It uses the compiled `idric-sms-request` program for deterministic
request parsing and a fake outbox for transport. It does not contain a language
model or a provider API.

The first runner uses UTC deliberately. A transport supplies a trusted telephone
address, receive time, and unique inbound message id:

```sh
idric_sms_service init ./state
idric_sms_service inbound ./state +15550000001 \
  2026-09-01T14:00:00Z in_000001 'REMIND 15:00'
idric_sms_service run_due ./state 2026-09-01T15:00:00Z
```

The receipt is:

```text
scheduled evt_in_000001 2026-09-01T15:00:00Z
sent evt_in_000001
```

and `state/fake_outbox/fake_evt_in_000001/body` contains `hey`.

## State transitions

```text
inbound/<inbound-id>/             trusted envelope plus original body
addresses/<telephone-address>     address-to-principal lookup
principals/<principal-id>/        unprivileged correspondent and addresses
consent/<event-id>/               exact authorization provenance
scheduled/<instant>/<event-id>/   durable pending event
sent/<event-id>/                  event moved here after fake delivery
cancelled/<event-id>/             event moved here by CANCEL or STOP
fake_outbox/<receipt>/             inspectable provider-independent delivery
opt_out/<principal-id>             durable STOP state
```

Creating a reminder creates directories and small ordinary files. Firing or
cancelling it is an atomic `mv` out of `scheduled/`. `STOP` creates an opt-out
marker and moves every pending event for that principal to `cancelled/`.
Possession of an address record never grants blanket permission: every outbound
event names one record under `consent/`, including the principal, destination,
request time, inbound id, original request, scheduled time, and message.

The unknown-caller path creates a `public_correspondent`, not a Unix account and
not a privileged Idriç principal. An explicit later enrollment mechanism may
promote or link principals without treating a telephone number as permanent
identity.

## Boundary

This repository owns command-line invocation and filesystem state transitions.
Idric-Net owns telephone, principal, message, request, authorization, and
transport meanings. The fake outbox is permanent diagnostic infrastructure. A
future provider, GSM-modem, or Android adapter should consume the same outbound
event rather than changing the scheduler's state model.

The service was moved from `isomorphisms/grease` PR #2, commit
`8b7968d70f6a7834961c1327d630b7853102ed51`. The move changes repository paths
and ownership documentation, not service behavior.
