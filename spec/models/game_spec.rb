# (c) goodprogrammer.ru

# Стандартный rspec-овский помощник для rails-проекта
require 'rails_helper'

# Наш собственный класс с вспомогательными методами
require 'support/my_spec_helper'

# Тестовый сценарий для модели Игры
#
# В идеале — все методы должны быть покрыты тестами, в этом классе содержится
# ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # Пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # Игра с прописанными игровыми вопросами
  let(:game_w_questions) do
    FactoryBot.create(:game_with_questions, user: user)
  end

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    describe '#create_game!' do
      it 'creates new correct game' do
        # Генерим 60 вопросов с 4х запасом по полю level, чтобы проверить работу
        # RANDOM при создании игры.
        generate_questions(60)

        game = nil

        # Создaли игру, обернули в блок, на который накладываем проверки
        expect {
          game = Game.create_game_for_user!(user)
          # Проверка: Game.count изменился на 1 (создали в базе 1 игру)
        }.to change(Game, :count).by(1).and(
          # GameQuestion.count +15
          change(GameQuestion, :count).by(15).and(
          # Game.count не должен измениться
            change(Question, :count).by(0)
          )
        )

        # Проверяем статус и поля
        expect(game.user).to eq(user)
        expect(game.status).to eq(:in_progress)

        # Проверяем корректность массива игровых вопросов
        expect(game.game_questions.size).to eq(15)
        expect(game.game_questions.map(&:level)).to eq (0..14).to_a
      end
    end
  end

  # Тесты на основную игровую логику
  context 'game mechanics' do
    # Правильный ответ должен продолжать игру
    describe '#answer.correct?' do
      it 'continues game if answer is correct' do
        # Текущий уровень игры и статус
        level = game_w_questions.current_level
        q = game_w_questions.current_game_question
        expect(game_w_questions.status).to eq(:in_progress)

        game_w_questions.answer_current_question!(q.correct_answer_key)

        # Перешли на след. уровень
        expect(game_w_questions.current_level).to eq(level + 1)

        # Ранее текущий вопрос стал предыдущим
        expect(game_w_questions.current_game_question).not_to eq(q)

        # Игра продолжается
        expect(game_w_questions.status).to eq(:in_progress)
        expect(game_w_questions.finished?).to be false
      end
    end

    describe '#take_money!' do
      it 'finishes the game' do
        # берем игру и отвечаем на текущий вопрос
        q = game_w_questions.current_game_question
        game_w_questions.answer_current_question!(q.correct_answer_key)

        # взяли деньги
        game_w_questions.take_money!

        prize = game_w_questions.prize
        expect(prize).to be > 0

        # проверяем что закончилась игра и пришли деньги игроку
        expect(game_w_questions.status).to eq :money
        expect(game_w_questions.finished?).to be true
        expect(user.balance).to eq prize
      end
    end
  end

  # группа тестов на проверку статуса игры
  context '.status' do
    # перед каждым тестом "завершаем игру"
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be true
    end
    
    describe '#status: won' do
      it 'returns game_status(:won)' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
        expect(game_w_questions.status).to eq(:won)
      end
    end
    
    describe '#status: fail' do
      it 'returns game_status(:fail)' do
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq(:fail)
      end
    end
    
    describe '#status: timeout' do
      it 'returns game_status(:timeout)' do
        game_w_questions.created_at = 1.hour.ago
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq(:timeout)
      end
    end
    
    describe '#status: money' do 
      it 'returns game_status(:money)' do
        expect(game_w_questions.status).to eq(:money)
      end
    end
  end

  describe '#current_game_question' do
    it 'returns current game question' do
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[0])
    end
  end
  
  describe '#previous_level' do
    it 'returns previous level of the game' do
      expect(game_w_questions.previous_level).to eq(-1)
    end
  end

  describe "#answer_current_question!" do
    context "when answer is correct" do
      let!(:q) { game_w_questions.current_game_question }
      let!(:level) { game_w_questions.current_level}
      let!(:answer_key) { game_w_questions.answer_current_question!(game_w_questions.current_game_question.correct_answer_key) }

      it 'game in progress' do 
        expect(answer_key).to be true
        expect(game_w_questions.current_level).to eq(1)
        expect(game_w_questions.finished?).to be false
      end      

      context "question is last" do
        let!(:level) { Question::QUESTION_LEVELS.max }
        let!(:game_w_questions) { FactoryBot.create(:game_with_questions, current_level: level) }

        it "rewards with prize" do
          expect(game_w_questions.prize).to eq(Game::PRIZES.max)
        end

        it "finishes with the game's status won" do
          expect(game_w_questions.status).to eq(:won)
        end
      end

      context "question is not last" do
        let!(:level) { rand(0..Question::QUESTION_LEVELS.max - 1) }
        let!(:game_w_questions) { FactoryBot.create(:game_with_questions, current_level: level) }

        it "moves to next level" do
          expect(game_w_questions.current_level).to eq(level + 1)
        end

        it "continues the game" do
          expect(game_w_questions.status).to eq(:in_progress)
        end
      end

      context "when time is over" do
        let!(:game_w_questions) { FactoryBot.create(:game_with_questions, created_at: 1.hours.ago) }

        it "finishes with the game's status timeout" do
          expect(game_w_questions.status).to eq(:timeout)
        end
      end
    end

    context "when answer is incorrect" do
      before(:each) do
        game_w_questions.answer_current_question!('b')
      end

      it "finishes the game" do
        expect(game_w_questions.finished?).to be true
      end

      it "finishes with the game's status fail" do
        expect(game_w_questions.status).to eq(:fail)
      end
    end
  end
end
