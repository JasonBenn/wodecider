#!/bin/env ruby
# encoding: utf-8
require 'pp'
require 'yaml'

class GymFinder
  @gym = ['Pull-up bar', 'Olympic bar and weights', 'Squat rack', 'Jumprope', 
    'Plyo box', 'Erg', 'Kettlebells',  'Medicine ball', 'Rings at muscle-up height', 
    'Rings at dip height', 'Climbing rope', 'Glute-ham developer', 'Flat bench', 
    'Dumbells', 'Medicine Ball', '', 'Partner', 'Rings', 'Box']
  class << self
    attr_accessor :gym
    
    def find
      puts "Wassup, champ! Ready to get swole??"
      puts "To start, I need to know what gear you've got. Below is a list of common" 
      puts "equipment. If you don't have one of these things in your gym, type its number"
      puts "and press ENTER and I'll remove it. When you're happy with your list,"
      puts "press ENTER again and I'll generate a WOD!\n\n"
      choice = "[user chooses]"
      until choice.empty?
        @gym.each_with_index {|equipment, i| puts "#{i+1}: #{equipment}"}
        choice = gets.chomp
        @gym = @gym - [gym[choice.to_i-1]]
        puts "Got it!\n\n"
      end
      @gym
    end

  end
end

class Parser
  attr_reader :workout_text, :dates, :indexes, :exercises, :suggestion
  attr_accessor :workouts

  Workout = Struct.new(:title, :description, :movements, :equipment)

  def initialize(args={})
    @workouts         = []
    @my_gym           = GymFinder.find
    @workout_text     = File.open(args[:workout_text]).read
    @exercises        = YAML::load(File.open(args[:exercises]).read)
    @dates, @indexes  = parse_text
    fill_titles
    fill_movements
    fill_equipment
    select_wods
    @suggestion       = nil
  end

  private

  def select_wods
    @workouts.select! do |workout|
      workout.equipment & @my_gym == workout.equipment
    end
    if @workouts.empty?
      puts "Sorry man, you don't have enough equipment for any of my workouts! Go for a run!"
      Process.exit
    end
  end

  def parse_text(search = 0, dates = [], indexes = [])
    date_regexp = /(January|February|March|April|May|June|July|August|September|October|November|December)\s\d{1,2},\s\d{4}/
    d = date_regexp.match(workout_text, search)
    dates   << d
    indexes << d.offset(0)
    parse_text(d.end(0), dates, indexes) unless (d.post_match =~ date_regexp) == nil
    return dates, indexes
  end

  def fill_titles
    for i in (0...dates.length) do 
      workouts << Workout.new(
        dates[i].to_s,
        fill_descriptions(i),
        [],
        [])
    end
  end

  def fill_movements
    all_movements = @exercises.values.flatten
    workouts.each do |workout|
      workout.movements = all_movements.select {|movement| workout.description.include? movement}
    end
  end

  def fill_equipment
    workouts.each do |workout|
      workout.movements.each do |movement|
        workout.equipment << exercises.select {|key, equipment| equipment.include?(movement)}.keys
      end
      workout.equipment = workout.equipment.flatten.uniq
    end
  end

  def fill_descriptions(i)
    workout_text[indexes[i][1]..(indexes[i+1].nil? ? -1 : indexes[i+1][0]-1)]
  end
end

class Navigator
  attr_reader :parser

  def initialize(parser)
    @parser = parser
  end

  def start
    next_menu = :display_next_workout
    while true
      puts "\n--------------\n"
      #menu = method(next_menu)
      next_menu, *args = send(next_menu, *args)
    end
  end

  def display_next_workout(workout = parser.workouts[rand(parser.workouts.length)])
    puts "\nAll right! Check this out:\n\n"
    @suggestion = workout
    puts "#{@suggestion.title}\n"
    puts "#{@suggestion.description}"
    return :next_steps
  end

  def next_steps
    puts "#1: This WOD looks legit, thanks! Exit WODecider."
    puts "#2: Meh. Bring me another!"
    puts "#3: List all #{parser.workouts.length} matches, by title, with summary of movements."
    puts "#4: Filter matches: require any of the #{generate_movements.length} movements."
    puts "#5: Filter matches: exclude any of the #{generate_movements.length} movements."
    puts "#6: Was this parsed correctly? I found #{@suggestion.movements.to_s}. Select here to update the database of movements."
    puts

    choice = gets.chomp

    case choice.to_i
      when 1 then Process::exit
      when 2 then return :different_wod
      when 3 then return :display_all_workouts
      when 4 then return :filter_require_movement
      when 5 then return :filter_exclude_movement
      when 6 then return :update_parser
      else puts "Not a number!"; return :next_steps
    end
  end

  def different_wod
    return :display_next_workout
  end

  def display_all_workouts
    parser.workouts.each_with_index do |workout, i|
      puts "#{i+1}: #{workout.title} with #{workout.movements.to_s}"
    end
    choice = gets.chomp
    display_next_workout(parser.workouts[choice.to_i-1])
  end

  def generate_movements
    parser.workouts.reduce([]) {|result, wod| result << wod.movements}.flatten.uniq
  end

  def filter_require_movement
    movements = generate_movements
    movements.each_with_index {|movement, i| puts "#{i+1}: #{movement}"}
    choice = gets.chomp
    parser.workouts.select! {|wod| wod.movements.include? movements[choice.to_i-1]}
    return :display_next_workout
  end

  def filter_exclude_movement
    movements = generate_movements
    movements.each_with_index {|movement, i| puts "#{i+1}: #{movement}"}
    choice = gets.chomp
    parser.workouts.reject! {|wod| wod.movements.include? movements[choice.to_i-1]}
    return :display_next_workout
  end

  def update_parser
    puts "Thanks. Which movement is missing?"
    movement = gets.chomp
    puts "And what bit of equipment does that require?"
    parser.exercises.keys.each_with_index {|equipment, i| puts "#{i+1}: #{equipment}" }
    equipment = parser.exercises.keys[gets.to_i-1]
    update_equipment(equipment, movement)
    puts "Sweet, all updated."
    return :display_next_workout, @suggestion
  end

  def update_equipment(equipment, movement)
    exercises = YAML::load(File.open('wodecider2_exercises2.txt').read)

    exercises[equipment] = exercises[equipment] << movement

    File.open('wodecider2_exercises2.txt', 'w') do |file|
      file.write(exercises.to_yaml)
    end
    @parser = Parser.new(workout_text: 'invictus_wods.txt', exercises: 'wodecider2_exercises2.txt')
  end

  at_exit do
    goodbyes = ["Have a good one!",
        "3..2..1.. GO!!",
        "Peace out, champ!"]
    puts goodbyes[rand(goodbyes.length)]
  end
end

parser = Parser.new(workout_text: 'invictus_wods.txt', exercises: 'exercises.txt')
Navigator.new(parser).start