Introduction: A feature-rich Pawn Shop system for FiveM servers using the ESX framework. This script allows players to pawn items and vehicles, creating a dynamic economy where unredeemed items flow back into a public marketplace.

Features:
Item & Vehicle Support: Supports both inventory items and owned vehicles.
Contract Lifecycle: Handles pawning, interest calculation, expiry dates, and automated marketplace transfers.
Advanced UI: Uses ox_lib context menus and dialogs for a modern, responsive feel.
Preview System: Built-in camera logic for inspecting marketplace vehicles.
Developer Friendly: Highly configurable config.lua and clean, documented code.

Installation:
Ensure you have ox_lib, ox_inventory, and oxmysql installed.
Clone this repository into your resources folder.
Import the provided .sql file into your database.
Configure your allowed items and pawn rates in config.lua.
Add ensure [Camou_RealPawnShop] to your server.cfg.

Requirements:
oxmysql
ox_lib
ox_inventory
