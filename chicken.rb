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
# Gamestate Class
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
  
  attr_accessor :bestMove
  attr_accessor :expectedScore
  
  attr_accessor :savedHash
    
  # Class Architecture
  
  # saving the hash reduces execution time to 75%
  def reHash
    h = @savedLasers.hash ^ (@savedTanks<<4).hash ^ (@savedHumans<<8).hash ^ (@savedCows<<12).hash ^ (@savedChickens<<16).hash
    @savedHash =  h ^ (@rolledLasers<<20).hash ^ (@rolledHumans<<24).hash ^ (@rolledCows<<28).hash ^ (@rolledChickens<<32).hash 
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
      other.rolledChickens == @rolledChickens
  end

  alias eql? ==
  
    
  # Create the object
  def initialize(lasers, tanks, humans, cows, chickens)
    @rolledLasers = lasers
    @rolledHumans = humans
    @rolledCows = cows
    @rolledChickens = chickens
    
    @savedLasers = 0
    @savedHumans = 0
    @savedCows = 0
    @savedChickens = 0
    @savedTanks = tanks
    
    @savedHash = nil
    self.reHash
    
  end

  # One cannot select something that has already been saved
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
    return result
  end


  # See if moves can be made
  def isEndState?
    return self.possibleMoves == []
  end

  # Say bye to everybody
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
    
    result = "Saved = #{saved}, available = #{possible}, possible moves = #{self.possibleMoves}, score = #{self.score}, #{self.isEndState?}"
  end

  def statesAfterMove(move)
    # assert self.possibleMoves.include?(move) , "Impossible move"
    stateAfterPick = self.clone
    
    case move
    when :saveLasersMove
      stateAfterPick.savedLasers = @savedLasers + @rolledLasers
      stateAfterPick.rolledLasers = 0;
    when :saveHumansMove
      # assert stateAfterPick.savedHumans == 0
      stateAfterPick.savedHumans = @rolledHumans
      stateAfterPick.rolledHumans = 0;
    when :saveCowsMove
      # assert stateAfterPick.savedCows == 0
      stateAfterPick.savedCows = @rolledCows
      stateAfterPick.rolledCows = 0;
    when :saveChickensMove
      # assert stateAfterPick.savedChickens == 0
      stateAfterPick.savedChickens = @rolledChickens
      stateAfterPick.rolledChickens = 0;
    else
      # assert false
    end
    stateAfterPick.reHash
    
    return stateAfterPick.allPossibleFollowStates
  end

  def allPossibleFollowStates
    result = []
    numberOfDice = @rolledLasers + @rolledHumans + @rolledCows + @rolledChickens
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
            aFollowState.savedTanks = tanks + @savedTanks
            
            aFollowState.reHash
            
            result.push(aFollowState)
          end      
        end      
      end
    end
   return result 
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
          shiftedAppendix << "..#{line}"
        end
        result << "\n#{shiftedAppendix}"
      end
    end
    
    return result
  end

  
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
    
    $calcsPerformed =     $calcsPerformed +1
    
    # else test all moves
    bestMove = nil
    bestScore = 0
    self.possibleMoves.each do |move|
      
      # for each move get the best distribution
      nextStates = self.statesAfterMove(move)
      sumScore = 0
      count = 0
      nextStates.each do |state|
        state.calculateWinningStrategy
        sumScore = sumScore + $savedStates[state]
        count = count + 1
      end
      
      expectedScoreForMove = sumScore / count
      if  expectedScoreForMove > bestScore
        bestScore = expectedScoreForMove
        bestmove = move
      end
      
    end

    @expectedScore = bestScore
    @bestMove = bestMove
    $savedStates[self] = @expectedScore

    
  end

end


# ===============================================================================================================
# Script
# ===============================================================================================================

def allStartingPositions
  numberOfDice = ARGV[0].to_i
  if numberOfDice == nil 
    numberOfDice = 2
  end
  
  baseState = GameState.new(0,0,0,0,numberOfDice)
  possibleFirstStates = baseState.allPossibleFollowStates
  
  possibleFirstStates.each do |state|
    puts state.recursiveDescription
    
  end
  
  puts "A total of #{possibleFirstStates.count} first positions are possible with #{numberOfDice} dice."
end


def evaluateHashPairs
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
  end
  puts "A total of #{collisionCount} collisions."
  
end


def calculateWinningStrategy
  numberOfDice = ARGV[0].to_i
  if numberOfDice == nil 
    numberOfDice = 2
  end
  
  baseState = GameState.new(0,0,0,0,numberOfDice)
  possibleFirstStates = baseState.allPossibleFollowStates
  
  possibleFirstStates.each do |state|
    state.calculateWinningStrategy
  end
  
  puts "A total of #{possibleFirstStates.count} first positions are possible with #{numberOfDice} dice."
  puts "A total of #{$savedStates.count} game states in total are possible with #{numberOfDice} dice."
  puts "A total of #{$calcsPerformed} recursiveSteps taken with #{numberOfDice} dice."
end

time do
  # allStartingPositions
  calculateWinningStrategy
  # evaluateHashPairs
end


