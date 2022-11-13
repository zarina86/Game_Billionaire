# (c) goodprogrammer.ru

require 'rails_helper'

# Тестовый сценарий для модели игрового вопроса, в идеале весь наш функционал
# (все методы) должны быть протестированы.
RSpec.describe GameQuestion, type: :model do
  # Задаем локальную переменную game_question, доступную во всех тестах этого
  # сценария: она будет создана на фабрике заново для каждого блока it,
  # где она вызывается.
  let(:game_question) do
    FactoryBot.create(:game_question, a: 2, b: 1, c: 4, d: 3)
  end

  # Группа тестов на игровое состояние объекта вопроса
  context 'game status' do
    # Тест на правильную генерацию хэша с вариантами
    describe '#variants' do
      it 'returns variants of answers' do
        expect(game_question.variants).to eq(
          'a' => game_question.question.answer2,
          'b' => game_question.question.answer1,
          'c' => game_question.question.answer4,
          'd' => game_question.question.answer3
        )
      end
    end
    
    describe '#answer_correct?' do
      it 'returns true if answer is correct answer' do
      # Именно под буквой b в тесте мы спрятали указатель на верный ответ
        expect(game_question.answer_correct?('b')).to be true
      end

      it 'returns false if answer is incorrect answer' do
        # Именно под буквой b в тесте мы спрятали указатель на верный ответ
          expect(game_question.answer_correct?('d')).to be false
      end
    end

    describe '#level' do 
      it 'returns correct level' do
        expect(game_question.level).to eq(game_question.question.level)
      end
    end

    describe '#text' do
      it 'returns correct text' do
        expect(game_question.text).to eq(game_question.question.text)
      end
    end
      
    describe '#correct_answer_key' do
      it 'returns correct answer key' do
        expect(game_question.correct_answer_key).to eq 'b'
      end
    end
  end
end