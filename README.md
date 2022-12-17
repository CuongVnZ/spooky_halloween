# Spooky Halloween

A simple 2D zombie survival game written in Ruby using the Gosu library. Players must survive waves of zombies and pick up items such as ammo and health to help them survive. The game is over when the player's health runs out.
## Requirements

- Ruby
- Gosu `(gem install gosu)`
- Halloweenpixels & Squares font (included in `attachments` directory)

## Running the game

To run the game, simply execute the file in Ruby:

``` sh
ruby spooky_halloween_structured.rb
```

## Gameplay

In the game, you play as a survivor trying to survive waves of zombies. Use the WASD keys to move and the mouse to aim and shoot. Pick up items such as ammo and health to help you survive. The game is over when your health runs out.

The game features several screens including a main menu, a play screen, a round screen, a game over screen, a profile screen, a high score screen, and an instruction screen.

The player has a maximum health of `PLAYER_MAX_HEALTH` and a maximum ammo of `PLAYER_MAX_AMMO`. The player's default velocity is `PLAYER_DEFAULT_VELOCITY`.

Zombies have a dimension size of `ZOMBIE_DIMENSION_SIZE_X` by `ZOMBIE_DIMENSION_SIZE_Y` and a default velocity of `ZOMBIE_DEFAULT_VELOCITY`. Their round multiplier is `ZOMBIE_ROUND_MULTIPLIER` and their default health is `ZOMBIE_DEFAULT_HEALTH`. Zombies are knocked back by `ZOMBIE_KNOCKBACK` units and their size is `ZOMBIE_SIZE` times their default size.

Bullets have a velocity of `BULLET_VELOCITY`.
## Configuration

Several game settings such as player and zombie attributes can be modified by changing the values of the global constants at the top of the file. The game can also be set to debug mode by setting the `DEBUG` constant to `true`.
## Classes and Modules

The game consists of several classes including `Player`, `Zombie`, `Bullet`, `Item`, and `Scheduler`. The `ZOrder` and `Screen` modules are also used.

The `Player` class has attributes for location, health, ammo, dimensions, and a flag for whether the player is dead. It also has an attribute for the mouse vector, which represents the direction the player is aiming.

The `Zombie` class has attributes for location, a direction vector, health, dimensions, and a flag for whether the zombie is dead.

The `Bullet` class has attributes for location, a direction vector, and dimensions.

The `Item` class has attributes for location, type, and dimensions. The `DropType` module defines constants for the types of items that can be dropped.

The `Scheduler` class has attributes for a time and a proc (a block of code). It is used to schedule events to occur after a certain time has passed.

The `GameWindow` class is the main class for the game and is responsible for handling input, updating the game state, and rendering the game. It is a subclass of Gosu::Window and overrides several methods from the parent class.
## Media

The game uses images and fonts for its graphics and UI. The images and fonts are stored in the media directory.

![alt text](/attachments/1.png)

![alt text](/attachments/2.png)