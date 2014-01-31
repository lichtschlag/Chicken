#!/usr/bin/env ruby

# ===============================================================================================================
# Martian Dice Solver
# Rules: http://boardgamegeek.com/boardgame/99875/martian-dice,  http://playtmg.com/products/martian-dice
# ===============================================================================================================

# ===============================================================================================================
# Helpers
# ===============================================================================================================

class AssertionError < RuntimeError
end

def assert
  raise AssertionError unless yield
end

def time
  start = Time.now
  yield
  executionTime = Time.now - start
  return executionTime
end


class String
  def is_integer?
    self.to_i.to_s == self
  end
end


# ===============================================================================================================
# Probability Functions
# ===============================================================================================================

class Fixnum
  @@factorialLookUp = []
  
  def self.computeFactorials
    for f in 0..20 do
      result = 1
      for i in 1..f do
        result = result * i
      end
      @@factorialLookUp[f] = result
    end
  end
  
  def factorial
    result = @@factorialLookUp[self]
  end
end


def permutationsOfDiceResult(m1, m2, m3, m4, m5)
  # Standard formula for a k-Combination with repretitions is n!/(m1! * m2! ... )
  n = m1 + m2 + m3 + m4 + m5
  # Here, m1 (the Lasers) apppears on 2 dice sides, so add 2^m1 term for all the permutations of the laser
  # e.g. L is double as likely as H, since L is on two of the six dice sides
  # but LLLH is 4 times as likely as LHHH
  return n.factorial.to_f / 
        ( m1.factorial * m2.factorial * m3.factorial * m4.factorial * m5.factorial) *
        2 ** m1
end


# ===============================================================================================================
# Global array of states that are already computed
# ===============================================================================================================

$expectedScores = {}
$bestMoves = {}
$calcsPerformed = 0


# ===============================================================================================================
# GameState Class
# ===============================================================================================================

class GameState
  
  attr_accessor :rolledLasers
  attr_accessor :rolledHumans
  attr_accessor :rolledCows
  attr_accessor :rolledChickens
  # tanks must always be saved

  attr_accessor :savedHumans
  attr_accessor :savedCows
  attr_accessor :savedLasers
  attr_accessor :savedTanks
  attr_accessor :savedChickens
  
  attr_accessor :diceToRoll
  
  # attr_accessor :bestMoves
  # attr_accessor :expectedScore
  
  attr_accessor :savedHash
  attr_accessor :rolledTanks     # only used to calc probability
  
    
  # Class Architecture -----------------------------------------------------------------------------------------
  
  # saving the hash reduces execution time to 75%
  def reHash
    @savedHash = @savedLasers.hash ^ (@savedTanks<<4).hash ^ (@savedHumans<<8).hash ^ (@savedCows<<12).hash \
                  ^ (@savedChickens<<16).hash ^ (@rolledLasers<<20).hash ^ (@rolledHumans<<24).hash \
                  ^ (@rolledCows<<28).hash ^ (@rolledChickens<<32).hash ^ (@diceToRoll<<36).hash 
  end

  
  def hash
    return @savedHash
  end
  

  def == (other)
    self.class === other and
      other.savedLasers == @savedLasers and
      other.savedTanks == @savedTanks and
      other.savedHumans == @savedHumans and
      other.savedCows == @savedCows and
      other.savedChickens == @savedChickens and
      other.rolledLasers == @rolledLasers and
      other.rolledHumans == @rolledHumans and
      other.rolledCows == @rolledCows and
      other.rolledChickens == @rolledChickens and
      other.diceToRoll == @diceToRoll
  end


  alias eql? ==
  
    
  # Constructor
  def initialize(diceToRoll)
    @rolledLasers = 0
    @rolledHumans = 0
    @rolledCows = 0
    @rolledChickens = 0
    
    @savedLasers = 0
    @savedHumans = 0
    @savedCows = 0
    @savedChickens = 0
    @savedTanks = 0
    
    @diceToRoll = diceToRoll
    
    @rolledTanks = 0
    
    @savedHash = nil
    self.reHash
  end
  
  
  # Game Logic ----------------------------------------------------------------------------------------------
  
  # One cannot select something that has already been saved, except lasers, which can alwyas be picked
  def possibleMoves
    result = []
    if @rolledLasers != 0
      result.push(:saveLasersMove)
    end
    if @rolledHumans != 0 && @savedHumans == 0 
      result.push(:saveHumansMove)
    end
    if @rolledCows != 0 && @savedCows == 0
      result.push(:saveCowsMove)
    end
    if @rolledChickens != 0 && @savedChickens == 0
      result.push(:saveChickensMove)
    end
    if @diceToRoll != 0
      # instead of rolling the player can end the game and keep the achieved score
      result.push(:rollDiceMove)
      result.push(:endGameMove)
    end
    return result
  end


  # An end state is reached, if the player can make no moves, including rolling
  def isEndState?
    return self.possibleMoves == []
  end
  

  def score
    bonus = 0
    if @savedHumans != 0 && @savedCows != 0 && @savedChickens != 0 
      bonus = 3
    end
    if @savedTanks > @savedLasers
      return 0
    end    
    return @savedHumans + @savedCows + @savedChickens + bonus
  end
  

  def statesAfterMove(move)
    # assert self.possibleMoves.include?(move) , "Impossible move"
    
    if move == :rollDiceMove 
      return self.allPossibleStatesAfterDiceRoll
    
    elsif
      stateAfterPick = self.clone      
      case move
      when :saveLasersMove
        stateAfterPick.savedLasers = @savedLasers + @rolledLasers
        stateAfterPick.rolledLasers = 0
      when :saveHumansMove
        # assert stateAfterPick.savedHumans == 0
        stateAfterPick.savedHumans = @rolledHumans
        stateAfterPick.rolledHumans = 0
      when :saveCowsMove
        # assert stateAfterPick.savedCows == 0
        stateAfterPick.savedCows = @rolledCows
        stateAfterPick.rolledCows = 0
      when :saveChickensMove
        # assert stateAfterPick.savedChickens == 0
        stateAfterPick.savedChickens = @rolledChickens
        stateAfterPick.rolledChickens = 0
      when :endGameMove
        stateAfterPick.diceToRoll = 0
      end
  
      stateAfterPick.diceToRoll = stateAfterPick.rolledLasers + stateAfterPick.rolledHumans \
                                  + stateAfterPick.rolledCows + stateAfterPick.rolledChickens
      stateAfterPick.rolledLasers = 0
      stateAfterPick.rolledHumans = 0
      stateAfterPick.rolledCows = 0
      stateAfterPick.rolledChickens = 0
  
      stateAfterPick.reHash
  
      return [stateAfterPick]
    end
  end


  def allPossibleStatesAfterDiceRoll
    result = []
    numberOfDice = @diceToRoll
    for lasers in 0..numberOfDice
      for tanks in 0..(numberOfDice-lasers)
        for humans in 0..(numberOfDice-lasers-tanks)
          for cows in 0..(numberOfDice-lasers-tanks-humans)
            chickens = (numberOfDice-lasers-tanks-humans-cows)
            
            aFollowState = self.clone
            aFollowState.rolledLasers = lasers
            aFollowState.rolledHumans = humans
            aFollowState.rolledCows = cows
            aFollowState.rolledChickens = chickens
            aFollowState.diceToRoll = 0
            aFollowState.savedTanks = @savedTanks + tanks
            
            # store tanks rolled, so that the state knows its probability
            aFollowState.rolledTanks = tanks
            
            aFollowState.reHash
            
            result.push(aFollowState)
          end      
        end      
      end
    end
   return result 
  end
  
  def probability
    permutationsOfDiceResult(@rolledLasers, @rolledTanks, @rolledHumans, @rolledCows, @rolledChickens)
  end
  
  
  # Output -----------------------------------------------------------------------------------------------
  
  def description
    saved = ""
    @savedLasers.times {saved << "L"}
    @savedTanks.times {saved << "T"}
    @savedHumans.times {saved << "H"}
    @savedCows.times {saved << "C"}
    @savedChickens.times {saved << "c"}

    possible = ""
    @rolledLasers.times {possible << "L"}
    @rolledHumans.times {possible << "H"}
    @rolledCows.times {possible << "C"}
    @rolledChickens.times {possible << "c"}
  
    if @diceToRoll == 0
      result = "╰─Saved = #{saved}, available = #{possible}, score = #{self.score}"
    else
      result = "╰─Saved = #{saved}, available #{diceToRoll} dice, score = #{self.score}"
    end
    
    expectedScore = $expectedScores[self]
    if expectedScore
      result << ", expectation = %2.2f" % expectedScore
    end
    if @rolledTanks
      result << ", p = %2.2f" % self.probability
    end
    
    result << ", possible moves = #{self.possibleMoves}"
    bestMove = $bestMoves[self]
    if bestMove
      result << ", suggestion = #{bestMove}"
    end
    
    return result  
  end
  
  
  def recursiveDescription(lastLine = false, depth = 5)
    result = self.description
    
    if !(depth >0) then 
      return result
    end
    possibleMoves = self.possibleMoves
    possibleMoves.each do |move|
      nextStates = self.statesAfterMove(move)
      nextStates.each do |state|
        stateIsLastLine = (state == nextStates.last && move == possibleMoves.last)
        appendix = state.recursiveDescription(stateIsLastLine, depth-1)
        shiftedAppendix = ""
        
        # This is very expensive to do
        if (lastLine)
          appendix.each_line do |line|
            shiftedAppendix << "  #{line}"
          end
        elsif
          appendix.each_line do |line|
            shiftedAppendix << "│ #{line}"
          end
        end
        result << "\n#{shiftedAppendix}"
      end
    end
    
    return result
  end


  # Recursion ---------------------------------------------------------------------------------------------
  
  def calculateWinningStrategy

    # if state already computed and saved in the global variable, leave
    if $expectedScores[self] != nil
      return
    end

    # if end state, then store and leave
    if self.isEndState?
      $expectedScores[self] = self.score
      $bestMoves[self] = nil
      return
    end
    
    # ok, we actually need to perform a recursive step here
    $calcsPerformed =  $calcsPerformed +1
    bestMoves = []
    bestScore = 0
    
    # for each move ...
    self.possibleMoves.each do |move|
      
      # ... calculate the expected score outcome ...
      expectedScoreForMove = 0;
      
      nextStates = self.statesAfterMove(move)
      
      # ... by calculating the average as the outcomes ...
      sumScore  = 0
      count     = 0
      nextStates.each do |state|
        state.calculateWinningStrategy
        # ... multiplied by its probability
        sumScore  = sumScore + $expectedScores[state] * state.probability
        count     = count + state.probability
      end        
      expectedScoreForMove = sumScore.to_f / count
      
      # ... and remember the moves with the best outcome
      if expectedScoreForMove > bestScore
        bestScore = expectedScoreForMove
        bestMoves = [move]
      elsif expectedScoreForMove == bestScore
        bestMoves.push(move)
      end
      
    end

    # push result to our results array
    # @expectedScore = bestScore
    # @bestMoves = bestMoves
    $expectedScores[self] = bestScore
    $bestMoves[self] = bestMoves

  end

end


# ===============================================================================================================
# Script
# ===============================================================================================================

def evaluateHashingFunction
  arrayOfAllKeysAndValues = $expectedScores.to_a
  arrayOfAllStates = []
  arrayOfAllKeysAndValues.each do |entry|
    arrayOfAllStates.push(entry[0])
  end
  
  max = arrayOfAllStates.count
  collisionCount = 0
  
  for i in 0..(max-1)
    for j in (i+1)..(max-1)
      hashCollistion = (arrayOfAllStates[i].hash == arrayOfAllStates[j].hash)
      if hashCollistion
        puts "collision between #{arrayOfAllStates[i].description} and #{arrayOfAllStates[j].description}"
        collisionCount = collisionCount +1
      end
    end
    if i % 1000 == 0
      puts "%2.2f%% done" % (i.to_f/max *100)
    end
  end
  puts "A total of #{collisionCount} hash collisions."
end


def calculateWinningStrategy
  $expectedScores = {}
  $bestMoves = {}
  
  numberOfDice = ARGV[0].to_i
  if numberOfDice == nil 
    numberOfDice = 2
  end
  
  baseState = GameState.new(numberOfDice)
  baseState.calculateWinningStrategy
  possibleFirstStates = baseState.statesAfterMove(:rollDiceMove)
  
  puts "A total of #{possibleFirstStates.count} dice rolls are possible in the first move with #{numberOfDice} dice."
  puts "A total of #{$expectedScores.count} game states in total are possible with #{numberOfDice} dice."
  puts "A total of #{$calcsPerformed} recursive steps taken with #{numberOfDice} dice."
  puts ""
end


def outputGameTree
  numberOfDice = ARGV[0].to_i
  if numberOfDice == nil 
    numberOfDice = 2
  end
  
  baseState = GameState.new(numberOfDice)
  puts "Tree of game states"
  puts baseState.recursiveDescription(true)
  puts ""
end


def outputStatistics
  results = {:firstStates => [], :savedStates => [], :expectedScore  => [], :timeToCalc  => [] }
  
  puts "Dice\t\tFirst States\tTotal States\tExpected Score\tComputation Time"
  
  for i in 1..13 do
    
    $expectedScores = {}
    $bestMoves = {}
    baseState = GameState.new(i)
    executionTime = time do
      baseState.calculateWinningStrategy
    end
    
    results[:firstStates][i]    = baseState.statesAfterMove(:rollDiceMove).count
    results[:savedStates][i]    = $expectedScores.count
    results[:expectedScore][i]  = $expectedScores[baseState]
    results[:timeToCalc][i]     = executionTime
    
    puts "%10d\t%12d\t%12d\t%14.2f\t\t%8.2f"\
          % [ i, results[:firstStates][i], results[:savedStates][i], results[:expectedScore][i], results[:timeToCalc][i] ]
  end
  puts ""
end


def giveMoveSuggestion(saved, options)
  if !saved || !options then
     puts "Did not understand parameters \"#{saved} #{options}\", usage \"./chicken.rb saved options\", e.g. \"./chicken.rb HHL 3\" or \"./chicken.rb THC, HLLC\""
     return
  end
  
  state = GameState.new(0)
  state.savedTanks = saved.count "tT"
  state.savedLasers = saved.count "lL"
  state.savedHumans = saved.count "hH"
  state.savedCows = saved.count "C"
  state.savedChickens = saved.count "c"

  if options.is_integer? then
    state.diceToRoll = options.to_i
  else
    state.rolledLasers = options.count "lL"
    state.rolledHumans = options.count "hH"
    state.rolledCows = options.count "C"
    state.rolledChickens = options.count "c"
  end
  
  state.calculateWinningStrategy
  puts state.recursiveDescription(true, 1)
  puts "\n"
  puts "You should #{$bestMoves[state]} for an expected score of #{$expectedScores[state]}\n"
end



# ---- Test Cases -----------------------------------------------------------------------------------------------

def testProbabilityFunctions
  assert {0.factorial == 1}
  assert {1.factorial == 1}
  assert {3.factorial == 6}
  assert {6.factorial == 720}
  
  assert { permutationsOfDiceResult(2,1,0,0,0) == 12}
  assert { permutationsOfDiceResult(1,2,0,0,0) == 6}
  assert { permutationsOfDiceResult(0,1,1,1,0) == 6}
  assert { permutationsOfDiceResult(0,3,0,0,0) == 1}
  assert { permutationsOfDiceResult(3,0,0,0,0) == 8}
end


def testGameStateClass
  assert { 
    testState = GameState.new(3)
    testState.probability == 1 
  }
  assert {
    testState = GameState.new(3)
    testState.rolledLasers = 2
    testState.rolledHumans = 1
    testState.probability == 12
  }
  assert {
    testState = GameState.new(3)
    testState.rolledLasers = 1
    testState.rolledHumans = 2
    testState.probability == 6
  }
  
end


def testCases
  testProbabilityFunctions
  testGameStateClass
end


# ---- Main Script ----------------------------------------------------------------------------------------------

execTime = time do
  Fixnum.computeFactorials
  # calculateWinningStrategy
  # outputGameTree
  # evaluateHashingFunction
  # outputStatistics
  # testCases
  giveMoveSuggestion(ARGV[0], ARGV[1])
end

puts "Script execution time: #{execTime} seconds\n"
