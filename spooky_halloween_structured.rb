require 'rubygems'
require 'gosu'
require "matrix"

# Global constants
WIN_WIDTH = 1024
WIN_HEIGHT = 576

# Game settings
PLAYER_MAX_HEALTH = 10
PLAYER_MAX_AMMO = 10
PLAYER_DEFAULT_VELOCITY = 3

BULLET_VELOCITY = 25

ZOMBIE_DIMENSION_SIZE_X = 30
ZOMBIE_DIMENSION_SIZE_Y = 30
ZOMBIE_DEFAULT_VELOCITY = 1.2
ZOMBIE_ROUND_MULTIPLIER = 2
ZOMBIE_DEFAULT_HEALTH = 3
ZOMBIE_KNOCKBACK = 10
ZOMBIE_SIZE = 1.5

# Debug settings
DEBUG = true

##########################
# Enumerations
##########################

module ZOrder
    LOWEST, LOW, MIDDLE, HIGH, HIGHEST = *0..4
end

module Screen
    MENU, PLAY, ROUND, GAME_OVER, PROFILE, HIGHSCORE, INSTRUCTION = *0..6
end

module DropType
    AMMO, HEART, SPEED = *0..2
end

##########################
# Records
##########################

class Player
    attr_accessor :loc_x, :loc_y, :health, :ammo, :dim, :dead, :mouse_vector

    def initialize (x, y)
        @loc_x = x 
        @loc_y = y

        @mouse_vector = Vector[0, 0]

        @health = 10
        @ammo = 10

        @dim = 30

        @dead = false
    end
end

# ----------------------------------------------
class Zombie
    attr_accessor :loc_x, :loc_y, :vector, :health, :dim, :dead

    def initialize (x, y)
        @loc_x = x 
        @loc_y = y

        @health = ZOMBIE_DEFAULT_HEALTH

        @vector = Vector[0, 0] # Direction vector = zero when initialize
        @dim = 20 * ZOMBIE_SIZE

        @dead = false
    end
end

# ----------------------------------------------
class Bullet
    attr_accessor :loc_x, :loc_y, :vector, :dim

    def initialize (x, y, vector)
        @loc_x = x 
        @loc_y = y
        @vector = vector # Vector must be defined when creating new instance of Bullet

        @dim = 5
    end    
end

# ----------------------------------------------
class Item
    attr_accessor :loc_x, :loc_y, :type, :dim

    def initialize (x, y, type)
        @loc_x = x 
        @loc_y = y
        @type = type

        @dim = 20
    end
end

# ----------------------------------------------
class Scheduler
    attr_accessor :time, :proc

    def initialize (proc, time)
        @time = Gosu.milliseconds + time
        @proc = proc
    end
end

##########################
# Gosu
##########################

class GameWindow < Gosu::Window
    # set up variables and attributes
    def initialize()
        super(WIN_WIDTH, WIN_HEIGHT, false)
        self.caption = "Spooky Halloween"

        # Font
        @info_font = Gosu::Font.new(self, "Squares", 30)
        @menu_font = Gosu::Font.new(self, "Squares", 40)
        @game_font = Gosu::Font.new(self, "Halloweenpixels", 40)
        @debug_font = Gosu::Font.new(15)

        # Game
        @option = 0
        @background = Gosu::Color::BLACK
        @menu_background = Gosu::Image.new("media/menu_bg.png")
        @game_background = Gosu::Image.new("media/game_bg.png")
        @schedulers = Array.new()

        @screen = Screen::MENU
        @score = 0
        @round = 0
        @game_over = false


        # Player
        @player = nil
        @name = ""
        @shoot_point = Gosu::Image.new("media/shoot_point.png")
        @shoot_sound = Gosu::Sample.new("audio/shoot.mp3")
        @death_sound = Gosu::Sample.new("audio/death.mp3")
        @heart_img = Gosu::Image.new("media/heart.png")
        @heart_border_img = Gosu::Image.new("media/heart_border.png")
        @gun_img = Gosu::Image.new("media/gun.png")

        # Bullet
        @bullets = Array.new()
        @bullet_img = Gosu::Image.new("media/bullet.png")

        # Zombie
        @zombies = Array.new()
        @zombie_spawns = Array.new()
        @zombie_spawns << [WIN_WIDTH/3, -50]
        @zombie_spawns << [WIN_WIDTH/3*2, -50]

        @zombie_spawns << [WIN_WIDTH/3, WIN_HEIGHT + 50]
        @zombie_spawns << [WIN_WIDTH/3*2, WIN_HEIGHT + 50]

        @zombie_spawns << [-50, WIN_HEIGHT/2]
        @zombie_spawns << [WIN_WIDTH+50, WIN_HEIGHT/2]
        
        @zombie_img = Gosu::Image.new("media/zombie.png")

        # Item Drop
        @drops = Array.new()
        @drop_bullet = Gosu::Image.new("media/drop_bullet.png")
        @drop_heart = Gosu::Image.new("media/drop_heart.png")
        @drop_speed = Gosu::Image.new("media/drop_bullet.png")

    end

    ##########################
    # Game handler procedures
    ##########################

    # ----------------------------------------------
    def player_handler()
        #sprite
        return if @player == nil

        10.times do |i|
            @heart_border_img.draw(20+30*i, 20, ZOrder::MIDDLE, 1.5, 1.5)
        end
        @player.health.times do |i|
            @heart_img.draw(20+30*i, 20, ZOrder::HIGH, 1.5, 1.5)
        end

        @info_font.draw_text("Health: #{@player.health}", 20, 50, ZOrder::HIGHEST)
        @info_font.draw_text("Ammo: #{@player.ammo}", 20, 80, ZOrder::HIGHEST)

        # Info
        @info_font.draw_text("Round #{@round}", 20, WIN_HEIGHT-100, ZOrder::HIGHEST)
        @info_font.draw_text("Score: #{@score}", 20, WIN_HEIGHT-70, ZOrder::HIGHEST)

        # Debug
        @debug_font.draw_text("Player X: #{@player.loc_x}", 500, WIN_HEIGHT-100, ZOrder::HIGHEST)
        @debug_font.draw_text("Player Y: #{@player.loc_y}", 500, WIN_HEIGHT-70, ZOrder::HIGHEST)

        #@player.render()
        if !@player.dead
            @debug_font.draw_text("#{@name}", @player.loc_x-30, @player.loc_y-20, ZOrder::MIDDLE)
        end
        dimension = get_dimension(@player)
        Gosu.draw_rect(dimension[0], dimension[1], 
            dimension[2]-dimension[0], dimension[3]-dimension[1],
            Gosu::Color::RED, ZOrder::LOWEST, mode=:default) #if DEBUG

        # Gun
        @player.mouse_vector = Vector[mouse_x - @player.loc_x, mouse_y - @player.loc_y].normalize()*35
        x = get_center_loc(@player)[0] + @player.mouse_vector[0]*1.5
        y = get_center_loc(@player)[1] + @player.mouse_vector[1]*1.5
        # Gosu.draw_rect(x-5, y-5, 10, 10, Gosu::Color::GREEN, ZOrder::HIGH, mode=:default) 
        degree = Math.atan2(@player.mouse_vector[0], @player.mouse_vector[1])*180/Math::PI
        @gun_img.draw_rot(x, y, ZOrder::HIGH, degree*-1, 0.5, 0.5, 0.2, 0.2)

        #player_shoot(mouse_x, mouse_y) if button_down?(Gosu::MsLeft)

        if @player.dead 
            game_over()
            @death_sound.play()
        end
    end
    
    def player_move()
        vector = Vector[0, 0]
        vector = vector + Vector[1, 0].normalize() if button_down?(Gosu::KbD)
        vector = vector + Vector[-1, 0].normalize() if button_down?(Gosu::KbA)
        vector = vector + Vector[0, 1].normalize() if button_down?(Gosu::KbS)
        vector = vector + Vector[0, -1].normalize() if button_down?(Gosu::KbW)

        # Iterate drops list and check if player move to collect
        @drops.length.times do |i|
            drop = @drops[i]
            next if drop == nil
            if check_collision(get_dimension(drop), get_dimension(@player))
                case drop.type
                    when DropType::AMMO
                        @player.ammo = PLAYER_MAX_AMMO
                    when DropType::HEART
                        @player.health = PLAYER_MAX_HEALTH
                end
                @drops.delete(drop)
            end
        end
        
        #@player.update()
        @player.loc_x += vector[0] * PLAYER_DEFAULT_VELOCITY
        @player.loc_y += vector[1] * PLAYER_DEFAULT_VELOCITY

        if (@player.loc_x < 0 || @player.loc_x > WIN_WIDTH-@player.dim ||
            @player.loc_y < 0 || @player.loc_y > WIN_HEIGHT-@player.dim)
            @player.dead = true
        end
    end

    def player_shoot(goal_x, goal_y)
        return if @player.dead
        if(@player.ammo > 0)
            spawn_x = get_center_loc(@player)[0] + @player.mouse_vector[0]
            spawn_y = get_center_loc(@player)[1] + @player.mouse_vector[1]
            vector = Vector[goal_x-spawn_x, goal_y-spawn_y].normalize()

            bullet = Bullet.new(spawn_x, spawn_y, vector)

            # Push bullet for render
            @bullets << bullet
            @player.ammo -= 1
            @shoot_sound.play
        end
    end

    # ----------------------------------------------
    def bullet_handler()
        @bullets.each do |bullet|
            next if bullet == nil

            #bullet.update()
            bullet.loc_x += bullet.vector[0] * BULLET_VELOCITY
            bullet.loc_y += bullet.vector[1] * BULLET_VELOCITY

            #bullet.render()
            # if (bullet.removed)
            #     #@color = Gosu::Color::GREY
            # end
            Gosu.draw_rect(bullet.loc_x, bullet.loc_y, 10, 10, Gosu::Color::YELLOW, ZOrder::MIDDLE, mode=:default)
            degree = Math.atan2(@player.mouse_vector[0], @player.mouse_vector[1])*180/Math::PI
            @bullet_img.draw_rot(bullet.loc_x+5, bullet.loc_y+5, ZOrder::HIGH, degree*-1, 0.5, 0.5, 0.4, 0.4)

            # Loop through each zombie
            @zombies.each do |zombie|
                next if zombie == nil || zombie.dead

                # Check collision
                if(check_collision(
                    get_dimension(bullet), 
                    get_dimension(zombie))
                )
                    zombie_hit_by_bullet(zombie, bullet)

                    #bullet.removed = true
                    @bullets.delete(bullet)
                end
            end
        end
    end

    # ----------------------------------------------
    def zombie_handler()
        # If there are no zombie left, let's start new round!
        if (@zombies.length <= 0) 
            start_new_round()
        else 
            @zombies.each do |zombie|
                #zombie.render()

                # Check if dead
                if (zombie.dead)
                    # zombie.color = Gosu::Color::GRAY
                end

                @debug_font.draw_text("#{zombie.health}", zombie.loc_x, zombie.loc_y-15, ZOrder::MIDDLE)

                dimension = get_dimension(zombie)
                width = dimension[2]-dimension[0]
                height = dimension[3]-dimension[1]
                Gosu.draw_rect(dimension[0], dimension[1], 
                    width, height,
                    Gosu::Color::BLUE, ZOrder::LOWEST, mode=:default) if DEBUG
                @zombie_img.draw_rot(zombie.loc_x+width/2, zombie.loc_y+height/2, ZOrder::HIGH, 1, 0.5, 0.5, 0.2*ZOMBIE_SIZE, 0.2*ZOMBIE_SIZE)
            end
        end
    end

    def zombie_move()
        @zombies.each do |zombie|
            next if zombie == nil || zombie.dead 

            return if @player.dead

            vec_x = @player.loc_x - zombie.loc_x
            vec_y = @player.loc_y - zombie.loc_y

            move_vector = Vector[vec_x, vec_y].normalize()

            # Iterate the remaining zombies
            @zombies.each do |zombie2|

                # Skip if it is the current zombie
                next if zombie2 == zombie

                # Avoid stucking
                if (zombie.loc_x == zombie2.loc_x && zombie.loc_y == zombie2.loc_y)

                    move_vector = Vector[10, 10]
                    zombie2.vector = Vector[-10, -10]
                end

                # Check for avoiding on duplicated location
                if(check_collision(
                    [
                        get_dimension(zombie)[0] + move_vector[0]*5, 
                        get_dimension(zombie)[1] + move_vector[1]*5, 
                        get_dimension(zombie)[2] + move_vector[0]*5, 
                        get_dimension(zombie)[3] + move_vector[1]*5
                    ],
                    get_dimension(zombie2))
                )
                    move_vector += -1*Vector[zombie2.loc_x - zombie.loc_x, zombie2.loc_y - zombie.loc_y].normalize()
                end
            end
            
            zombie.vector = move_vector

            #zombie.update()
            if zombie.vector != nil
                zombie.loc_x += zombie.vector[0] * ZOMBIE_DEFAULT_VELOCITY
                zombie.loc_y += zombie.vector[1] * ZOMBIE_DEFAULT_VELOCITY
            end
            
            if(check_collision(get_dimension(zombie), get_dimension(@player)))
                #@player.hit(zombie)
                knochback = zombie.vector
                @player.loc_x += knochback[0] * 10
                @player.loc_y += knochback[1] * 10
    
                @player.health -= 1
                @player.dead = true if(@player.health <= 0)
            end
        end
    end
    
    # When zombie was hit by bullet
    def zombie_hit_by_bullet(zombie, bullet)
        return if zombie.dead

        knochback = bullet.vector
        zombie.loc_x += knochback[0] * ZOMBIE_KNOCKBACK
        zombie.loc_y += knochback[1] * ZOMBIE_KNOCKBACK

        zombie.health -= 1
        if(zombie.health <= 0)
            zombie.dead = true
            @score += 1

            schedule(Proc.new {
                @zombies.delete(zombie)

                type = DropType::AMMO
                chance = rand(100)
                if chance <= 40
                    type = DropType::AMMO
                end
                if chance <= 10
                    type = DropType::HEART
                end

                drop = Item.new(zombie.loc_x, zombie.loc_y, type)
                @drops << drop
                schedule(Proc.new {
                    @drops.delete(drop)
                }, 10000) # Disappear after 10 seconds
            }, 500)
        end

        # Change color when zombie was hit
        # zombie.color = Gosu::Color::GRAY
        # schedule(Proc.new {
        #     zombie.color = Gosu::Color::BLUE
        # }, 200)
    end

    # ----------------------------------------------
    def drop_handler()
        @drops.length.times do |i|
            drop = @drops[i]
            #drop.render()
            case drop.type
                when DropType::AMMO
                    @drop_bullet.draw(drop.loc_x, drop.loc_y, ZOrder::MIDDLE, 0.05, 0.05)
                    @debug_font.draw_text("ammo", drop.loc_x-5, drop.loc_y-15, ZOrder::MIDDLE)
                    #Gosu.draw_rect(drop.loc_x, drop.loc_y, drop.dim, drop.dim, Gosu::Color::YELLOW, ZOrder::LOWEST, mode=:default)
                when DropType::HEART
                    @drop_heart.draw(drop.loc_x, drop.loc_y, ZOrder::MIDDLE, 0.02, 0.02)
                    @debug_font.draw_text("heart", drop.loc_x-5, drop.loc_y-15, ZOrder::MIDDLE)
            end
        end
    end

    # ----------------------------------------------
    def start_new_round()
        @screen = Screen::ROUND

        @round += 1
        #puts 'hi new round'
        @bullets.clear()
        @zombies.clear()

        amount = @round * ZOMBIE_ROUND_MULTIPLIER
        amount.to_i.times do |i|
            spawn_id = rand(@zombie_spawns.length)
            @zombies << zombie = Zombie.new(@zombie_spawns[spawn_id][0], @zombie_spawns[spawn_id][1])
        end

        schedule(Proc.new {
            @screen = Screen::PLAY
        }, 500)
    end

    def game_over()
        file = File.new("profile/#{@name}.txt", "w")
        file.puts(@round)
        file.puts(@score)
        file.close
        puts '[INFO] Game over'

        @game_over = true
        @zombies.clear()
        @bullets.clear()
        @drops.clear()
        @round = 0
        @score = 0
        @player = nil
        
        @screen = Screen::GAME_OVER
    end

    ##########################
    # Util functions
    ##########################

    def check_collision(dim1, dim2)
        if(check_point_dimension([dim1[0], dim1[1]], dim2) ||
            check_point_dimension([dim1[0], dim1[3]], dim2) ||
            check_point_dimension([dim1[2], dim1[1]], dim2) ||
            check_point_dimension([dim1[2], dim1[3]], dim2))
            return true
        end
        return false
    end

    def check_point_dimension(point, dimension)
        if(
            (point[0] > dimension[0] && point[0] < dimension[2] &&
            point[1] > dimension[1] && point[1] < dimension[3])
        )
            return true
        end
        return false
    end

    def get_dimension(object)
        return [object.loc_x, object.loc_y, object.loc_x + object.dim, object.loc_y + object.dim]
    end

    def get_center_loc(object)
        dimension = get_dimension(object)
        offset_x = (dimension[2] - dimension[0])/2
        offset_y = (dimension[3] - dimension[1])/2
        return [object.loc_x + offset_x, object.loc_y + offset_y]
    end

    # --------------------
    def schedule(prop, time)
        scheduler = Scheduler.new(prop, time)
        @schedulers << scheduler
    end

    def scheduler_check()
        current = Gosu.milliseconds
        @schedulers.length.times do |i|
            scheduler = @schedulers[i]
            return if scheduler == nil
            if(current >= scheduler.time)
                scheduler.proc.call()
                @schedulers.delete(scheduler)
            end
        end
    end

    ##########################
    # SCREENS
    ##########################

    def menu_screen()
        fx = WIN_WIDTH.to_f/@menu_background.width.to_f
        fy = WIN_HEIGHT.to_f/@menu_background.height.to_f
        @menu_background.draw(0, 0, ZOrder::LOWEST, fx, fy)

        @game_font.draw_text("Spooky   Halloween", 80, 50, ZOrder::HIGHEST, 2.5, 2.5, Gosu::Color::YELLOW)

        @menu_font.draw_text("Play", 80, WIN_HEIGHT/2-70, ZOrder::HIGHEST, 0.7, 0.7)
        @menu_font.draw_text("Instruction", 80, WIN_HEIGHT/2, ZOrder::HIGHEST, 0.7, 0.7)
        @menu_font.draw_text("Highscore", 80, WIN_HEIGHT/2+70, ZOrder::HIGHEST, 0.7, 0.7)
        @menu_font.draw_text("Exit", 80, WIN_HEIGHT/2+140, ZOrder::HIGHEST, 0.7, 0.7)

        case @option
            when 0
                @menu_font.draw_text(">", 40, WIN_HEIGHT/2-70, ZOrder::HIGHEST, 0.7, 0.7, Gosu::Color::FUCHSIA)
            when 1
                @menu_font.draw_text(">", 40, WIN_HEIGHT/2, ZOrder::HIGHEST, 0.7, 0.7, Gosu::Color::FUCHSIA)
            when 2
                @menu_font.draw_text(">", 40, WIN_HEIGHT/2+70, ZOrder::HIGHEST, 0.7, 0.7, Gosu::Color::FUCHSIA)
            when 3
                @menu_font.draw_text(">", 40, WIN_HEIGHT/2+140, ZOrder::HIGHEST, 0.7, 0.7, Gosu::Color::FUCHSIA)
        end
        @debug_font.draw_text("Press 'SPACE' to select", 80, WIN_HEIGHT-50, ZOrder::HIGHEST)
    end

    def profile_screen()
        text = "Enter your name" 
        @game_font.draw_text(text, 80, 40, ZOrder::HIGHEST)
        @debug_font.draw_text("(8 characters maximun)", 80, 100, ZOrder::HIGHEST, 1.5, 1.5)
        width = @game_font.text_width(text)
        @debug_font.draw_text("#{@name}", 400, 55, ZOrder::HIGHEST, 2, 2)
        @debug_font.draw_text("Press 'SPACE' to continue", 80, WIN_HEIGHT-50, ZOrder::HIGHEST)
    end

    def instruction_screen()
        text = "Instruction"
        @game_font.draw_text(text, 80, 40, ZOrder::HIGHEST)
        @debug_font.draw_text("1. Use A,S,W,D button to move arround", 80, 100, ZOrder::HIGHEST, 2, 2)
        @debug_font.draw_text("2. Left mouse button to fire", 80, 140, ZOrder::HIGHEST, 2, 2)
        @debug_font.draw_text("3. Move to item drops to collect them", 80, 180, ZOrder::HIGHEST, 2, 2)
        @debug_font.draw_text("4. Survive as long as possible to achieve the highest score!", 80, 220, ZOrder::HIGHEST, 2, 2)
        @debug_font.draw_text("Press 'SPACE' to continue", 80, WIN_HEIGHT-50, ZOrder::HIGHEST)
        
    end

    def highscore_screen()
        hash = {}
        Dir.children("profile").each do |fName|
            file = File.new("profile/"+fName, "r") # open for reading
            hash[fName] = file.gets.to_i
        end
        hash = hash.sort_by(&:last).reverse
        text = "Highscore"
        @game_font.draw_text(text, 80, 40, ZOrder::HIGHEST)
        i = 0
        hash.each do |key,value|
            i += 1
            @debug_font.draw_text(key, 80, 100+60*i, ZOrder::HIGHEST, 2, 2)
            width = @game_font.text_width(text)
            @debug_font.draw_text(value, 80, 130+60*i, ZOrder::HIGHEST, 2, 2)
        end
        @debug_font.draw_text("Press 'SPACE' to continue", 80, WIN_HEIGHT-50, ZOrder::HIGHEST)
    end

    def round_screen()
        @info_font.draw_text("ROUND ##{@round.to_s}", WIN_WIDTH/2-70, WIN_HEIGHT/2, ZOrder::HIGHEST)
        #@info_font.draw_text("Press 'SPACE' to continue", WIN_WIDTH/2-210, WIN_HEIGHT-50, ZOrder::HIGHEST)
    end

    def play_screen()
        return if @game_over

        fx = WIN_WIDTH.to_f/@menu_background.width.to_f
        fy = WIN_HEIGHT.to_f/@menu_background.height.to_f
        @game_background.draw(0, 0, ZOrder::LOWEST,fx, fy)

        # Handle objects render
        bullet_handler()
        drop_handler()
        zombie_handler()
        player_handler()
    end

    def game_over_screen()
        @info_font.draw_text("GAME OVER!", 300, 235, ZOrder::HIGHEST, 2, 2)
        text = "Press  'SPACE'  to  continue"
        width = @info_font.text_width(text)
        @info_font.draw_text(text, WIN_WIDTH/2-width/2, WIN_HEIGHT-50, ZOrder::HIGHEST)
    end
    

    ##########################
    # Gosu main producers
    ##########################

    def update()
        if @screen == Screen::PLAY && @game_over == false
            player_move()
            zombie_move()
        end
        scheduler_check()
    end

    def draw()
        # Background
        Gosu.draw_rect(0, 0, WIN_WIDTH, WIN_HEIGHT, @background, ZOrder::LOWEST, mode=:default)

        # Screen render
        case @screen
            when Screen::MENU
                menu_screen()
            when Screen::PROFILE
                profile_screen()
            when Screen::INSTRUCTION
                instruction_screen()
            when Screen::HIGHSCORE
                highscore_screen()
            when Screen::ROUND
                round_screen()
            when Screen::PLAY
                play_screen()
            when Screen::GAME_OVER
                game_over_screen()
        end

        @shoot_point.draw_rot(mouse_x, mouse_y, ZOrder::HIGHEST)

        # Debug display
        @debug_font.draw_text("Mouse X: #{mouse_x}", 700, WIN_HEIGHT-100, ZOrder::HIGHEST)
        @debug_font.draw_text("Mouse y: #{mouse_y}", 700, WIN_HEIGHT-70, ZOrder::HIGHEST)
        @debug_font.draw_text("Milliseconds: #{Gosu.milliseconds}", 700, WIN_HEIGHT-50, ZOrder::HIGHEST)
    end

    def needs_cursor?; false; end

    def button_down(id)
        if id == Gosu::KbEscape && @screen == Screen::PLAY 
            @screen = Screen::MENU 
            game_over()
        end

        case @screen
            when Screen::MENU
                case id
                    when Gosu::KbSpace
                        case @option
                            when 0
                                @screen = Screen::PROFILE
                            when 1
                                @screen = Screen::INSTRUCTION
                            when 2
                                @screen = Screen::HIGHSCORE
                            when 3
                                exit 1
                        end
                    when Gosu::KB_UP
                        @option -= 1
                        @option = 0 if @option < 0
                    when Gosu::KB_DOWN
                        @option += 1
                        @option = 3 if @option > 3
                end
            # -------------------- #
            when Screen::PROFILE
                if 3 < id and id < 30
                    @name =  @name + (id+61).chr
                end
                if @name.size >= 9
                    @name = @name.chop
                end
                if id == Gosu::KB_BACKSPACE
                    @name = @name.chop
                end
                if id == Gosu::KbSpace && @name != ""
                    @game_over = false
                    @player = Player.new(WIN_WIDTH/2, WIN_HEIGHT/2)
                    start_new_round()
                    puts "[INFO] Start new game"
                end
            # -------------------- #
            when Screen::ROUND
                case id
                    when Gosu::KbSpace
                        #@screen = Screen::PLAY
                end
            # -------------------- #
            when Screen::INSTRUCTION
                case id
                    when Gosu::KbSpace
                        @screen = Screen::MENU
                end
            # -------------------- #
            when Screen::HIGHSCORE
                case id
                    when Gosu::KbSpace
                        @screen = Screen::MENU
                end
            # -------------------- #
            when Screen::PLAY
                case id
                    when Gosu::MsLeft
                        player_shoot(mouse_x, mouse_y)
                    when Gosu::KbR
                        # @player.ammo = 10 # Using for debug
                end
            # -------------------- #
            when Screen::GAME_OVER
                case id
                    when Gosu::KbSpace
                        @screen = Screen::MENU
                end
        end
    end
end

# Lets get started!
GameWindow.new.show()