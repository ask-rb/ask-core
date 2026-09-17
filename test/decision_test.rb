# frozen_string_literal: true

require_relative "test_helper"

class DecisionTest < Minitest::Test
  # --- the three question types ---

  def test_choice_carries_its_options_as_a_wire_format
    question = Ask::Decision::Choice.new(
      instructions: "Which team should handle this?",
      criteria: {billing: "Payment issues", technical: "Bugs"}
    )

    assert_equal :choice, question.type
    assert_equal(
      {type: "choice", instructions: "Which team should handle this?",
       criteria: {billing: "Payment issues", technical: "Bugs"}},
      question.to_h
    )
  end

  def test_noul_is_a_yes_or_no
    question = Ask::Decision::Noul.new(instructions: "Does this convey urgency?")

    assert_equal :noul, question.type
    assert_equal "noul", question.to_h[:type]
  end

  def test_score_keeps_its_levels_in_order
    question = Ask::Decision::Score.new(
      instructions: "How urgent is this?",
      criteria: ["Not urgent", "Somewhat urgent", "Very urgent"]
    )

    assert_equal :score, question.type
    assert_equal ["Not urgent", "Somewhat urgent", "Very urgent"], question.to_h[:criteria]
  end

  def test_a_score_needs_something_to_score_against
    assert_raises(ArgumentError) do
      Ask::Decision::Score.new(instructions: "How urgent?", criteria: ["Only one"])
    end
  end

  # --- what comes back ---

  def test_a_choice_answer_ranks_its_options
    answer = Ask::DecisionResult::ChoiceAnswer.new(
      id: "route",
      choice: "billing",
      probabilities: {"billing" => 0.8, "technical" => 0.2},
      confidence: 0.8
    )

    assert_equal "billing", answer.choice
    assert_equal [["billing", 0.8], ["technical", 0.2]], answer.ranked
    assert answer.confident?(0.7)
    refute answer.confident?(0.9)
  end

  def test_a_noul_answer_is_a_probability_without_a_confidence
    answer = Ask::DecisionResult::NoulAnswer.new(id: "urgent", noul: 0.96)

    assert_equal 0.96, answer.noul
    assert answer.yes?
    refute answer.no?
    assert_in_delta 0.46, answer.strength
  end

  # The raw accessor answers "is the probability at or above the midpoint",
  # which at exactly the midpoint is a coin flip either way. Code deciding
  # whether to *act* on it wants a threshold of its own, above 0.5.
  def test_a_noul_that_says_nothing_is_a_coin_flip
    answer = Ask::DecisionResult::NoulAnswer.new(id: "urgent", noul: 0.5)

    assert answer.yes?
    assert_equal 0.0, answer.strength
  end

  def test_a_batch_answers_by_id
    batch = Ask::DecisionResult::Batch.new(
      answers: {"route" => Ask::DecisionResult::ChoiceAnswer.new(
        id: "route", choice: "billing", probabilities: {}, confidence: 0.9
      )},
      model: "jev-1.13.0",
      usage: {"input_tokens" => 346}
    )

    assert_equal "billing", batch["route"].choice
    assert_equal "jev-1.13.0", batch.model
    assert_nil batch["nothing_asked"]
  end

  # --- the registry ---

  def test_a_provider_registers_and_resolves_by_name
    Ask::DecisionProvider.register(:fake, FakeProvider)

    assert_equal FakeProvider, Ask::DecisionProvider.resolve(:fake)
  end

  def test_resolving_a_provider_that_was_never_registered_says_so
    assert_raises(Ask::Error) { Ask::DecisionProvider.resolve(:nobody) }
  end

  class FakeProvider < Ask::DecisionProvider
    def evaluate(state:, decisions:, model: nil)
      Ask::DecisionResult::Batch.new(answers: {}, model: model)
    end
  end
end
