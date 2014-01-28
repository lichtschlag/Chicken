# ===============================================================================================================
# Martian Dice Solver
# Rules: 13 dice, 6 sices
# ===============================================================================================================

# ===============================================================================================================
# Helpers
# ===============================================================================================================

def time
  start = Time.now
  yield
  puts "Execution time: #{Time.now - start} seconds"
end


# ===============================================================================================================
# Global array of states that are already computed
# ===============================================================================================================

$savedStates = {}
$calcsPerformed = 0


# ===============================================================================================================
# GameState Class
# ===============================================================================================================

class GameState
  
  attr_accessor :rolledLasers
  attr_accessor :rolledHumans
  attr_accessor :rolledCows
  attr_accessor :rolledChickens
  #tanks must always be saved

  attr_accessor :savedHumans
  attr_accessor :savedCows
  attr_accessor :savedLasers
  attr_accessor :savedTanks
  attr_accessor :savedChickens
  
  attr_accessor :diceToRoll
  
  attr_accessor :bestMoves
  attr_accessor :expectedScore
  
  attr_accessor :savedHash
    
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
            
            aFollowState.reHash
            
            result.push(aFollowState)
          end      
        end      
      end
    end
   return result 
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
      result = "Saved = #{saved}, available = #{possible}, possible moves = #{self.possibleMoves}, score = #{self.score}"
    else
      result = "Saved = #{saved}, available  #{diceToRoll} dice, possible moves = #{self.possibleMoves}, score = #{self.score}"
    end
    
    expectedScore = $savedStates[self]
    if expectedScore
      result << ", \t\texpectation = %2.2f" % expectedScore
    end
    
  end
  
  
  def recursiveDescription
    result = self.description
    
    self.possibleMoves.each do |move|
      nextStates = self.statesAfterMove(move)
      nextStates.each do |state|
        appendix = state.recursiveDescription
        shiftedAppendix = ""
        
        # This takes up about half of the computation time
        appendix.each_line do |line|
          shiftedAppendix << ". #{line}"
        end
        result << "\n#{shiftedAppendix}"
      end
    end
    
    return result
  end


  # Recursion ---------------------------------------------------------------------------------------------
  
  def calculateWinningStrategy

    # if state already computed and saved in the global variable, leave
    if $savedStates[self] != nil
      return
    end

    # if end state, then store and leave
    if self.isEndState?
      @expectedScore = self.score
      @bestMove = nil
      $savedStates[self] = @expectedScore
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
      
      # ... and for now, calculate the average as the outcome
      sumScore  = 0
      count     = 0
      nextStates.each do |state|
        state.calculateWinningStrategy
        sumScore  = sumScore + $savedStates[state]
        count     = count + 1
      end        
      expectedScoreForMove = sumScore.to_f / count
      
      # ... and remember the moves with the best outcome
      if  expectedScoreForMove > bestScore
        bestScore = expectedScoreForMove
        bestMoves = [move]
      elsif expectedScoreForMove == bestScore
        bestMoves.push(move)
      end
      
    end

    # push result to our results array
    @expectedScore = bestScore
    @bestMoves = bestMoves
    $savedStates[self] = @expectedScore

  end

end


# ===============================================================================================================
# Script
# ===============================================================================================================

def evaluateHashingFunction
  arrayOfAllKeysAndValues = $savedStates.to_a
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
  numberOfDice = ARGV[0].to_i
  if numberOfDice == nil 
    numberOfDice = 2
  end
  
  baseState = GameState.new(numberOfDice)
  baseState.calculateWinningStrategy
  possibleFirstStates = baseState.statesAfterMove(:rollDiceMove)
  
  # puts baseState.recursiveDescription
  
  puts "A total of #{possibleFirstStates.count} dice rolls are possible in the first move with #{numberOfDice} dice."
  puts "A total of #{$savedStates.count} game states in total are possible with #{numberOfDice} dice."
  puts "A total of #{$calcsPerformed} recursive steps taken with #{numberOfDice} dice."
end


def outputGameTree
  numberOfDice = ARGV[0].to_i
  if numberOfDice == nil 
    numberOfDice = 2
  end
  
  baseState = GameState.new(numberOfDice)
  puts baseState.recursiveDescription
end


def outputStatistics
  results = {:firstStates => [], :savedStates => [], :expectedScore  => [], :timeToCalc  => [] }
  
  puts "Dice\t\tFirst States\tTotal States\tExpected Score\tComputation Time"
  
  for i in 1..13 do
    
    $savedStates = {}
    
    baseState = GameState.new(i)
    start = Time.now
    baseState.calculateWinningStrategy
    executionTime = Time.now - start

    
    results[:firstStates][i]    = baseState.statesAfterMove(:rollDiceMove).count
    results[:savedStates][i]    = $savedStates.count
    results[:expectedScore][i]  = $savedStates[baseState]
    results[:timeToCalc][i]     = executionTime
    
    puts "%10d\t%12d\t%12d\t%14.2f\t\t%8.2f"\
          % [ i, results[:firstStates][i], results[:savedStates][i], results[:expectedScore][i], results[:timeToCalc][i] ]
    
  end
end


# ---- Main Script ----------------------------------------------------------------------------------------------

time do
  calculateWinningStrategy
  # outputGameTree
  # evaluateHashingFunction
  outputStatistics
end


