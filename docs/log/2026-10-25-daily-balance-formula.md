# Clarify separation of the cashbox share from daily expenses

Status: the interpretation behind 1.10.0 was withdrawn following owner clarification, and the application was restored to 1.9.0. Date: 2026-10-25. Source: owner clarification and the Daily Expenses screenshot.

## Clarification and rollback

A shared expense remains one item, but only its daily share enters the daily-expense total; its cashbox share is displayed and charged to the cashbox alone. The definition of saved total balance does not change: it remains as before 1.10.0 and stays fixed when a later deposit from the remainder is recorded. The 1.10.0 interpretation that changed the balance formula was rolled back. Historical records were unchanged.

The daily PDF uses saved total balance. Legacy accounts recovering a missing balance retain the previous migration rules.

## Verification

Tests confirm that a shared expense of 30,000, allocated 10,000 to daily funds and 20,000 to the cashbox, adds only the daily share to daily expenses. The cashbox share remains separate. Application tests passed after restoring the previous formula.

## Installation

Restored `/Users/eros/Applications/Daftar-1.9.0-before-daily-balance.app` to `/Users/eros/Applications/Daftar.app` and verified version 1.9.0. Version 1.10.0 remains preserved for reference if needed.
