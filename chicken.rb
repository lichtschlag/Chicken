# Martian Dice Solver
# Rules: 13 dice, 6 sices

def time
  start = Time.now
  yield
  puts "Execution time: #{Time.now - start} seconds"
end


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
  def isEndState
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
    
    result = "Saved = #{saved}, available = #{possible}, possible moves = #{self.possibleMoves}, score = #{self.score}"
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
        appendix.each_line do |line|
          shiftedAppendix << "..#{line}"
        end
        result << "\n#{shiftedAppendix}"
      end
    end
    
    return result
    
  end
end


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



time do
  allStartingPositions
end

